import 'package:analyzer/analyzer.dart';
import 'package:codemod/codemod.dart';

import '../../constants.dart';
import '../../util.dart';

final _mixinIgnoreComment = buildIgnoreComment(
  mixinOfNonClass: true,
  undefinedClass: true,
);

// TODO: Can we use an ElementVisitor to definitively determine whether a mixin type is an over_react mixin? Otherwise we will hit false positives (e.g. `DebounceStateMixin`)
class PropsAndStateMixinUsageUpdater extends RecursiveAstVisitor
    with AstVisitingSuggestorMixin
    implements Suggestor {
  @override
  visitWithClause(WithClause node) {
    final allMixins = node.mixinTypes.map((n) => n.name.name);
    final targetMixins = allMixins
        // Ignore mixin types that were added already via this codemod.
        .where((n) => !n.startsWith(generatedPrefix))
        // Only select mixin types that are _likely_ over_react mixins.
        .where((n) => n.endsWith('PropsMixin') || n.endsWith('StateMixin'))
        // Filter out those that already have a `$`-prefixed partner.
        .where((n) => !allMixins.contains(generatedPrefix + n));

    if (targetMixins.isEmpty) {
      return;
    }

    for (final mixinType in node.mixinTypes) {
      if (targetMixins.contains(mixinType.name.name)) {
        final typeArgs = mixinType.typeArguments?.toSource() ?? '';
        yieldPatch(
          mixinType.end,
          mixinType.end,
          [
            ',',
            '    $_mixinIgnoreComment',
            '    ${generatedPrefix}${mixinType.name.name}$typeArgs',
          ].join('\n'),
        );
      }
    }
  }
}
