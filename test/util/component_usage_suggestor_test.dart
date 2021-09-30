import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:over_react_codemod/src/util/component_usage_migrator.dart';
import 'package:test/test.dart';

import '../resolved_file_context.dart';
import '../util.dart';

main() {
  group('ComponentUsageMigrator', () {
    late SharedAnalysisContext sharedContext;

    setUpAll(() async {
      sharedContext = SharedAnalysisContext.overReact;
      await sharedContext.init();
    });

    group('identifies web_skin_dart component usages', () {});

    group('throws when a component usage is not resolved', () {
      test('', () async {
        const unresolvedUsages = [
          'Foo()()',
          '(Foo()..bar = "baz")()',
          'Dom.div()()',
          'builder()',
        ];

        for (final usage in unresolvedUsages) {
          final migrator = GenericMigrator(
            onMigrateUsage: boundExpectAsync2((_, __) {},
                count: 0,
                reason: 'migrator should not be called for any of these usages;'
                    ' it should throw first'),
          );

          final context = await sharedContext.resolvedFileContextForTest(
            // We're intentionally not importing over_react here since we don't
            // want things like Dom.div to resolve.
            'usage() => $usage;',
            // Don't pre-resolve, otherwise resolvedFileContextForTest might throw.
            // We want to see how the migrator handles it when it's the first
            // thing that resolves a file.
            preResolveFile: false,
            throwOnAnalysisErrors: false,
          );
          await expectLater(
            () async => await migrator(context).toList(),
            throwsA(isA<Exception>().havingToStringValue(allOf(
              contains('Builder static type could not be resolved'),
              contains(usage),
            ))),
          );
        }
      });

      test(
          'but not for resolved dynamic calls might look like unresolved usages',
          () async {
        // Valid dynamic calls that are resolved and just looks like usages
        const source = /*language=dart*/ '''
            // Dynamic first and second invocation
            dynamic Foo1;
            usage1() => Foo1()();
            
            // Static first invocation, dynamic second invocation
            dynamic Foo2() {}
            dynamic builder2;
            usage2_1() => Foo2()();
            usage2_2() => builder2();
            
            // Static first/second invocation, dynamic return value
            dynamic Function() Foo3() {}
            dynamic builder3() {}
            usage3_1() => Foo3()();
            usage3_2() => builder3();
       ''';

        final migrator = GenericMigrator(
          onMigrateUsage: boundExpectAsync2((_, __) {},
              count: 0, reason: 'these calls should not be detected as usages'),
        );
        // awaiting this is the best way to assert it does not throw, since
        // returnsNormally doesn't work as intended with async functions.
        await sharedContext.getPatches(migrator, source);
      });
    });

    group('calls migrateUsage for each component usage', () {
      test('only if shouldMigrateUsage returns MigrationDecision.shouldMigrate',
          () async {
        final migrateUsageCalls = <FluentComponentUsage>[];
        await sharedContext.getPatches(
          GenericMigrator(
            onMigrateUsage: (_, usage) => migrateUsageCalls.add(usage),
            onShouldMigrateUsage: (_, usage) {
              switch (usage.builder.toSource()) {
                case 'Dom.div()':
                  return MigrationDecision.notApplicable;
                case 'Dom.span()':
                  return MigrationDecision.shouldMigrate;
                case 'Dom.a()':
                  return MigrationDecision.needsManualIntervention;
              }
              throw ArgumentError('Unexpected builder');
            },
          ),
          withOverReactImport(/*language=dart*/ '''
              usages() => [
                Dom.div()(),
                Dom.span()(),
                Dom.a()(),
              ];
          '''),
        );
        expect(migrateUsageCalls.map((u) => u.builder.toSource()).toList(), [
          'Dom.span()',
        ]);
      });

      test('for all types of components', () async {
        final migrateUsageCalls = <FluentComponentUsage>[];
        await sharedContext.getPatches(
          GenericMigrator(
            onMigrateUsage: (_, usage) => migrateUsageCalls.add(usage),
          ),
          withOverReactImport(/*language=dart*/ '''
              UiFactory Foo;
              UiFactory Bar;
              UiProps builder;
              dynamic notAUsage() {}
              dynamic alsoNotAUsage;
                        
              usages() => Foo()(
                (Bar()..id = 'something')(),
                Dom.div()(),
                builder(),
                notAUsage(),
                alsoNotAUsage,
              );
          '''),
        );

        expect(migrateUsageCalls.map((u) => u.builder.toSource()).toList(), [
          'Foo()',
          'Bar()',
          'Dom.div()',
          'builder',
        ]);
      });
    });

    group('common usage flagging', () {
      group('of untyped props:', () {
        const constantsSource = /*language=dart*/ '''
        
          const dataFooConst = 'data-foo';
          const somethingElseConst = 'somethingElse';
          
          class Foo {
            static const dataFooConst = 'data-foo';
            static const somethingElseConst = 'somethingElse';
          }
        ''';

        test('does not flag valid usages', () async {
          await testSuggestor(
            suggestor: GenericMigrator(
              onMigrateUsage: boundExpectAsync2((_, __) {},
                  // This suggestor gets run twice since idempotency is tested.
                  count: 2,
                  reason: 'should have run on the valid component usage'),
            ),
            resolvedContext: sharedContext,
            input: /*language=dart*/ withOverReactImport('''
                contents() => (Dom.div()
                  ..addProp('data-foo', '')
                  ..addProp(dataFooConst, '')
                  ..addProp(Foo.dataFooConst, '')
                  ..['data-foo'] = ''
                  ..[dataFooConst] = ''
                  ..[Foo.dataFooConst] = ''
                  // ignore: not_enough_positional_arguments
                  ..addProp() /* bad call */
                )();
                $constantsSource
            '''),
          );
        });

        test('flags usages as expected', () async {
          await testSuggestor(
            suggestor: GenericMigrator(),
            resolvedContext: sharedContext,
            input: /*language=dart*/ withOverReactImport('''
                bool condition;
            
                contents() => (Dom.div()
                  ..addProp('somethingElse', '')
                  ..addProp(somethingElseConst, '')
                  ..addProp(Foo.somethingElseConst, '')
                  ..['somethingElse'] = ''
                  ..[somethingElseConst] = ''
                  ..[Foo.somethingElseConst] = ''
                  ..[condition ? 'data-foo' : 'data-bar'] = ''
                )();
                $constantsSource
            '''),
            expectedOutput: /*language=dart*/ withOverReactImport('''
                bool condition;
                
                contents() => (Dom.div()
                  // FIXME(mui_migration) - addProp - manually verify prop key
                  ..addProp('somethingElse', '')
                  // FIXME(mui_migration) - addProp - manually verify prop key
                  ..addProp(somethingElseConst, '')
                  // FIXME(mui_migration) - addProp - manually verify prop key
                  ..addProp(Foo.somethingElseConst, '')
                  // FIXME(mui_migration) - operator[]= - manually verify prop key
                  ..['somethingElse'] = ''
                  // FIXME(mui_migration) - operator[]= - manually verify prop key
                  ..[somethingElseConst] = ''
                  // FIXME(mui_migration) - operator[]= - manually verify prop key
                  ..[Foo.somethingElseConst] = ''
                  // FIXME(mui_migration) - operator[]= - manually verify prop key
                  ..[condition ? 'data-foo' : 'data-bar'] = ''
                )();
                $constantsSource
            '''),
          );
        });
      });

      group('methods:', () {
        test('flags method calls other than addTestId', () async {
          await testSuggestor(
            suggestor: GenericMigrator(),
            resolvedContext: sharedContext,
            input: /*language=dart*/ withOverReactImport('''            
                content() => (Dom.div()
                  ..addProps({})
                  ..modifyProps((_) {})
                  ..addTestId("foo")
                )();
            '''),
            expectedOutput: /*language=dart*/ withOverReactImport('''
                content() => (Dom.div()
                  // FIXME(mui_migration) - addProps call - manually verify
                  ..addProps({})
                  // FIXME(mui_migration) - modifyProps call - manually verify
                  ..modifyProps((_) {})
                  ..addTestId("foo")
                )();
            '''),
          );
        });
      });

      test('flags static extension getters and setters', () async {
        const extensionSource = /*language=dart*/ '''
            extension on DomProps {
              get extensionGetter => null;
              set extensionSetter(value) {}
            }
        ''';

        await testSuggestor(
          suggestor: GenericMigrator(),
          resolvedContext: sharedContext,
          input: /*language=dart*/ withOverReactImport('''
              content() => (Dom.div()
                ..extensionGetter
                ..extensionSetter = 'foo'
              )();
              
              $extensionSource
          '''),
          expectedOutput: /*language=dart*/ withOverReactImport('''
              content() => (Dom.div()
                // FIXME(mui_migration) - extensionGetter (extension) - manually verify
                ..extensionGetter
                // FIXME(mui_migration) - extensionSetter (extension) - manually verify
                ..extensionSetter = 'foo'
              )();
              
              $extensionSource
          '''),
        );
      });
    });

    group('migratePropsByName', () {
      test('runs the migrator for each prop with a matching name', () async {
        final suggestor = GenericMigrator(onMigrateUsage: (migrator, usage) {
          migrator.migratePropsByName(
            usage,
            migratorsByName: {
              'onClick': boundExpectAsync1((p) {
                expect(p.name.name, 'onClick');
              }),
              'href': boundExpectAsync1((p) {
                expect(p.name.name, 'href');
              }),
              'target': boundExpectAsync1((_) {},
                  count: 0,
                  reason: 'should not call props that are not present'),
            },
            catchAll: boundExpectAsync1((p) {
              expect(p.name.name, 'id');
            }),
          );
        });
        final source = withOverReactImport(/*language=dart*/ '''
            content() => (Dom.div()
              ..onClick = (_) {}
              ..href = "example.com"
              ..id = "foo"
            )();
        ''');
        await sharedContext.getPatches(suggestor, source);
      });

      test('throws when a prop does not exist on the props class', () async {
        final suggestor = GenericMigrator(onMigrateUsage: (migrator, usage) {
          migrator.migratePropsByName(usage, migratorsByName: {
            'notARealProp': (_) {},
          });
        });

        final source = withOverReactImport('content() => Dom.div()();');
        expect(
            () async => await sharedContext.getPatches(suggestor, source),
            throwsA(isA<ArgumentError>().havingMessage(allOf(
              contains("'migratorsByName' contains unknown prop name"),
              contains("notARealProp"),
            ))));
      });
    });
  });
}

Func1<T, A> boundExpectAsync1<T, A>(T Function(A) callback,
        {int count = 1, int max = 0, String? id, String? reason}) =>
    expectAsync1(callback, count: count, max: max, id: id, reason: reason);

Func2<T, A, B> boundExpectAsync2<T, A, B>(T Function(A, B) callback,
        {int count = 1, int max = 0, String? id, String? reason}) =>
    expectAsync2(callback, count: count, max: max, id: id, reason: reason);

extension on TypeMatcher<ArgumentError> {
  Matcher havingMessage(dynamic matcher) =>
      having((e) => e.message, 'message', matcher);
}

Matcher hasPatchText(dynamic matcher) => isA<Patch>().havingText(matcher);

Matcher isMuiMigrationFixmeCommentPatch({String withMessage = ''}) =>
    hasPatchText(matches(
      RegExp(r'// FIXME\(mui_migration\) - .+ - ' + RegExp.escape(withMessage)),
    ));

extension on TypeMatcher<Patch> {
  Matcher havingText(dynamic matcher) =>
      having((p) => p.updatedText, 'updatedText', matcher);
}

extension on TypeMatcher<Object> {
  Matcher havingToStringValue(dynamic matcher) =>
      having((p) => p.toString(), 'toString() value', matcher);
}

typedef OnMigrateUsage = void Function(
    GenericMigrator migrator, FluentComponentUsage usage);
typedef OnShouldMigrateUsage = MigrationDecision Function(
    GenericMigrator migrator, FluentComponentUsage usage);

class GenericMigrator with ClassSuggestor, ComponentUsageMigrator {
  final OnMigrateUsage? onMigrateUsage;
  final OnShouldMigrateUsage? onShouldMigrateUsage;

  GenericMigrator({this.onMigrateUsage, this.onShouldMigrateUsage});

  @override
  MigrationDecision shouldMigrateUsage(usage) =>
      onShouldMigrateUsage?.call(this, usage) ??
      MigrationDecision.shouldMigrate;

  @override
  void migrateUsage(usage) {
    super.migrateUsage(usage);
    onMigrateUsage?.call(this, usage);
  }
}

const overReactImport = "import 'package:over_react/over_react.dart';";

String withOverReactImport(String source) {
  return '$overReactImport\n$source';
}

String fileWithCascadeOnUsage(String cascade) {
  return withOverReactImport('content() => (Dom.div()\n$cascade\n)())');
}
