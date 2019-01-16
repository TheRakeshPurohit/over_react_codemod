import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

import '../../constants.dart';
import '../../util.dart';

/// Suggestor that inserts a static `meta` field to every props and state mixin
/// class so that consumers who may be using `$Props()` or `$PropKeys()` on the
/// mixin will be able to use the new Dart 2-compatible alternative.
class PropsAndStateMixinMetaAdder extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitClassDeclaration(ClassDeclaration node) {
    // Only looking for @PropsMixin() and @StateMixin() classes.
    String metaType;
    final isOverReactMixin = node.metadata.any((annotation) {
      if (overReactMixinAnnotationNames.contains(annotation.name.name)) {
        metaType =
            annotation.name.name.contains('Props') ? 'PropsMeta' : 'StateMeta';
        return true;
      }
      return false;
    });
    if (!isOverReactMixin) {
      return;
    }

    final targetMetaInitializer =
        '${privateGeneratedPrefix}metaFor${node.name.name}';

    final existingMetaField = node.getField('meta');
    if (existingMetaField == null) {
      // Meta field needs to be added.
      final ignoreComment = buildIgnoreComment(
        constInitializedWithNonConstantValue: true,
        undefinedClass: true,
        undefinedIdentifier: true,
      );
      yieldPatch(
        node.leftBracket.end,
        node.leftBracket.end,
        [
          '',
          '  $ignoreComment',
          '  static const $metaType meta = $targetMetaInitializer;',
          '',
        ].join('\n'),
      );
    } else {
      // Meta field already exists.
      if (existingMetaField.initializer.toSource() != targetMetaInitializer) {
        // But, it isn't initialized correctly, so update it.
        yieldPatch(
          existingMetaField.initializer.offset,
          existingMetaField.initializer.end,
          targetMetaInitializer,
        );
      }
    }
  }
}
