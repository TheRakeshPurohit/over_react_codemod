// Copyright 2021 Workiva Inc.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:over_react_codemod/src/theme_provider_suggestors/theme_provider_adder.dart';
import 'package:test/test.dart';

import '../util.dart';

main() {
  group('ReactDomRenderMigrator', () {
    final testSuggestor = getSuggestorTester(ThemeProviderAdder('wkTheme'));

    test('empty file', () async {
      await testSuggestor(expectedPatchCount: 0, input: '');
    });

    test('no matches', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          library foo;
          var a = 'b';
          class Foo {}
        ''',
      );
    });

    // todo also add testcase for already updated errorboudndary wtih thteme provider
    test('render usage not from react or over_react', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          import 'dart:html';

          import 'package:somewhere_else/react_dom.dart' as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
      );
    });

    test('render usage from react', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'dart:html';
          
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'dart:html';
          
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('render usage from over_react', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'dart:html';
          
          import 'package:over_react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'dart:html';
          
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:over_react/react_dom.dart' as react_dom;

          main() {
            react_dom.render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('render usage with different namespace', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'dart:html';
          
          import 'package:over_react/react_dom.dart' as some_other_namespace;

          main() {
            some_other_namespace.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'dart:html';
          
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:over_react/react_dom.dart' as some_other_namespace;

          main() {
            some_other_namespace.render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('render usage with no namespace', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'dart:html';
          
          import 'package:react/react_dom.dart';

          main() {
            render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'dart:html';
          
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:react/react_dom.dart';

          main() {
            render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('when the ThemeProvider import already exists', () async {
      await testSuggestor(
        expectedPatchCount: 2,
        input: '''
          import 'dart:html';
          
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'dart:html';
        
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('render usage with ErrorBoundary', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'dart:html';
          
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(ErrorBoundary()(Foo()()), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'dart:html';
          
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(ErrorBoundary()((ThemeProvider()..theme = wkTheme)(Foo()())), mountNode);
          }
        ''',
      );
    });

    test('render usage with ErrorBoundary with props', () async {
      await testSuggestor(
        expectedPatchCount: 3,
        input: '''
          import 'dart:html';
          
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render((ErrorBoundary()
              ..onComponentDidCatch = (error, _) => true
            )(Foo()()), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'dart:html';
          
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render((ErrorBoundary()
              ..onComponentDidCatch = (error, _) => true
            )((ThemeProvider()..theme = wkTheme)(Foo()())), mountNode);
          }
        ''',
      );
    });

    test('with a different added theme', () async {
      await getSuggestorTester(ThemeProviderAdder('anotherTheme'))(
        expectedPatchCount: 3,
        input: '''
          import 'dart:html';
          
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
        expectedOutput: '''
          import 'dart:html';
          
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render((ThemeProvider()..theme = anotherTheme)(Foo()()), mountNode);
          }
        ''',
      );
    });

    test('no react_dom.dart import but usage has namespace in a `part of` file',
        () async {
      await testSuggestor(expectedPatchCount: 2, input: '''
          part of 'a_file.dart';

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''', expectedOutput: '''
          part of 'a_file.dart';

          main() {
            react_dom.render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
          }
        ''');
    });

    group('render usage already wrapped in ThemeProvider', () {
      test('', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
          import 'dart:html';

          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
          }
        ''',
        );
      });

      test('with ErrorBoundary', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
          import 'dart:html';
          
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(ErrorBoundary()((ThemeProvider()..theme = wkTheme)(Foo()())), mountNode);
          }
        ''',
        );
      });

      test('with ErrorBoundary with props', () async {
        await testSuggestor(
          expectedPatchCount: 0,
          input: '''
          import 'dart:html';
          
          import 'package:react_material_ui/styles/theme_provider.dart';
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render((ErrorBoundary()
              ..onComponentDidCatch = (error, _) => true
            )((ThemeProvider()..theme = wkTheme)(Foo()())), mountNode);
          }
        ''',
        );
      });
    });

    group('render usage in a test directory', () {
      test('', () async {
        await getSuggestorTester(ThemeProviderAdder('wkTheme'),
            inputUrl: 'test/input')(
          expectedPatchCount: 0,
          input: '''
          import 'dart:html';
          
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
        );
      });

      test('nested', () async {
        await getSuggestorTester(ThemeProviderAdder('wkTheme'),
            inputUrl: 'subpackages/a_package/test/input')(
          expectedPatchCount: 0,
          input: '''
          import 'dart:html';
          
          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
        );
      });
    });

    test('a method not called render', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          import 'dart:html';

          import 'package:react/react_dom.dart' as react_dom;

          main() {
            react_dom.render2(Foo()(), mountNode);
          }
        ''',
      );
    });

    test('render usage not from react or over_react', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          import 'dart:html';

          import 'package:somewhere_else/react_dom.dart' as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
      );
    });

    test('render usage not from react_dom', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          import 'dart:html';

          import 'package:react/somewhere_else.dart' as react_dom;

          main() {
            react_dom.render(Foo()(), mountNode);
          }
        ''',
      );
    });

    test('render usage with wrong namespace', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          import 'dart:html';

          import 'package:react/react_dom.dart' as some_namespace;

          main() {
            a_different_namespace.render(Foo()(), mountNode);
          }
        ''',
      );
    });

    test('render usage with no namespace and no react_dom  import', () async {
      await testSuggestor(
        expectedPatchCount: 0,
        input: '''
          main() {
            render(Foo()(), mountNode);
          }
        ''',
      );
    });

    // test('simple usage', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 3,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         var instance = react_dom.render(Foo()(), mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         var instance = react_dom.render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //
    // test('simple usage already wrapped with ErrorBoundary that has props',
    //     () async {
    //   await testSuggestor(
    //     expectedPatchCount: 5,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         react_dom.render((ErrorBoundary()..prop = true)(Foo()()), mountNode);
    //         react_dom.render((ErrorBoundary()..prop = true)(foo), mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         react_dom.render((ErrorBoundary()..prop = true)((ThemeProvider()..theme = wkTheme)(Foo()())), mountNode);
    //         react_dom.render((ErrorBoundary()..prop = true)((ThemeProvider()..theme = wkTheme)(foo)), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //
    // test('simple usage as an argument', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 3,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         var instance = getDartComponent(react_dom.render(Foo()(), mountNode));
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         var instance = getDartComponent(react_dom.render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode));
    //       }
    //     ''',
    //   );
    // });
    //
    // test('simple usage as a return value', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 3,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         return react_dom.render(Foo()(), mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         return react_dom.render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //
    // test('simple usage with existing other props', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 3,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         var instance = react_dom.render((Foo()
    //           ..id = 'foo'
    //         )(), mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         var instance = react_dom.render((ThemeProvider()..theme = wkTheme)((Foo()
    //           ..id = 'foo'
    //         )()), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //

    //
    // test('simple usage with non-component usage', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 9,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         var instance1 = react_dom.render(foo(), mountNode);
    //
    //         var instance2 = react_dom.render(foo, mountNode);
    //
    //         instance3 = react_dom.render(foo(), mountNode);
    //
    //         instance4 = react_dom.render(foo, mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as react_dom;
    //
    //       main() {
    //         var instance1 = react_dom.render((ThemeProvider()..theme = wkTheme)(foo()), mountNode);
    //
    //         var instance2 = react_dom.render((ThemeProvider()..theme = wkTheme)(foo), mountNode);
    //
    //         instance3 = react_dom.render((ThemeProvider()..theme = wkTheme)(foo()), mountNode);
    //
    //         instance4 = react_dom.render((ThemeProvider()..theme = wkTheme)(foo), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //

    //
    // test('import with double quotes', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 3,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import "package:react/react_dom.dart" as react_dom;
    //
    //       main() {
    //         react_dom.render(Foo()(), mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import "package:react/react_dom.dart" as react_dom;
    //
    //       main() {
    //         react_dom.render(ErrorBoundary()(Foo()()), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //
    // test('imported from `over_react` with namespace', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 3,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import 'package:over_react/react_dom.dart' as different_namespace;
    //
    //       main() {
    //         different_namespace.render(Foo()(), mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:over_react/react_dom.dart' as different_namespace;
    //
    //       main() {
    //         different_namespace.render(ErrorBoundary()(Foo()()), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //
    // test('imported from `over_react` without namespace', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 3,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import 'package:over_react/react_dom.dart';
    //
    //       main() {
    //         render(Foo()(), mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:over_react/react_dom.dart';
    //
    //       main() {
    //         render(ErrorBoundary()(Foo()()), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //
    // test('different import namespace', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 3,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as different_namespace;
    //
    //       main() {
    //         different_namespace.render(Foo()(), mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart' as different_namespace;
    //
    //       main() {
    //         different_namespace.render(ErrorBoundary()(Foo()()), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //
    // test('no import namespace', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 3,
    //     input: '''
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart';
    //
    //       main() {
    //         render(Foo()(), mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart';
    //
    //       main() {
    //         render(ErrorBoundary()(Foo()()), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //
    // test('no react_dom.dart import', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 0,
    //     input: '''
    //       main() {
    //         render(Foo()(), mountNode);
    //       }
    //     ''',
    //   );
    // });
    //
    //
    // test('no react_dom.dart import but usage has namespace', () async {
    //   await testSuggestor(expectedPatchCount: 3, input: '''
    //       main() {
    //         react_dom.render(Foo()(), mountNode);
    //       }
    //     ''', expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //
    //       main() {
    //         react_dom.render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
    //       }
    //     ''');
    // });
    //
    // test('no import of over_react but is wrapped with ErrorBoundary', () async {
    //   await testSuggestor(
    //     expectedPatchCount: 3,
    //     input: '''
    //       import 'package:react/react_dom.dart';
    //
    //       main() {
    //         render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
    //       }
    //     ''',
    //     expectedOutput: '''
    //       import 'package:react_material_ui/styles/theme_provider.dart';
    //       import 'package:over_react/over_react.dart';
    //       import 'package:react/react_dom.dart';
    //
    //       main() {
    //         render((ThemeProvider()..theme = wkTheme)(Foo()()), mountNode);
    //       }
    //     ''',
    //   );
    // });
  });
}
