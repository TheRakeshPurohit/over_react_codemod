// Copyright 2023 Workiva Inc.
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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:logging/logging.dart';

import '../util.dart';
import '../util/class_suggestor.dart';
import '../util/element_type_helpers.dart';
import '../util/importer.dart';
import 'constants.dart';

final _log = Logger('UnifyRenameSuggestor');

/// Suggestor that performs all the updates needed to migrate from the react_material_ui package
/// to the unify_ui package:
///
/// - Rename specific components and objects
/// - Update WSD ButtonColor usages
/// - Add fix me comments for manual checks
///
/// Also see migration guide: https://github.com/Workiva/react_material_ui/tree/master/react_material_ui#how-to-migrate-from-reactmaterialui-to-unifyui
class UnifyRenameSuggestor extends GeneralizingAstVisitor with ClassSuggestor {
  UnifyRenameSuggestor();

  /// Whether or not to add [unifyWsdUri] import.
  late bool needsWsdImport;

  @override
  visitIdentifier(Identifier node) {
    super.visitIdentifier(node);

    // Check that the parent isn't a prefixed identifier to avoid conflicts if the parent was already updated.
    if (node.parent is PrefixedIdentifier) {
      return;
    }

    final identifier = node.tryCast<SimpleIdentifier>() ??
        node.tryCast<PrefixedIdentifier>()?.identifier;
    final uri = identifier?.staticElement?.source?.uri;
    final prefix = node.tryCast<PrefixedIdentifier>()?.prefix;

    if (uri != null &&
        (isUriWithinPackage(uri, 'react_material_ui') ||
            isUriWithinPackage(uri, 'unify_ui'))) {
      // Update components and objects that were renamed in unify_ui.
      final newName = rmuiToUnifyIdentifierRenames[identifier?.name];
      if (identifier != null && newName != null) {
        if (newName.startsWith('Wsd')) {
          needsWsdImport = true;
          // Overwrite namespace as well because wsd import will be added with no namespace.
          yieldPatch(newName, node.offset, node.end);
        } else {
          yieldPatch(newName, identifier.offset, identifier.end);
        }
      }

      // Update WSD ButtonColor and AlertSize usages.
      {
        // Update WSD constant properties objects to use the WSD versions if applicable.
        yieldWsdRenamePatchIfApplicable(
            Expression node, String? objectName, String? propertyName) {
          const wsdConstantNames = [
            'AlertSize',
            'AlertColor',
            'AlertVariant',
            'AlertSeverity',
            'LinkButtonType',
            'LinkButtonSize',
          ];
          if (objectName == 'ButtonColor' &&
              (propertyName?.startsWith('wsd') ?? false)) {
            needsWsdImport = true;
            yieldPatch('WsdButtonColor.$propertyName', node.offset, node.end);
          } else if (wsdConstantNames.contains(objectName)) {
            needsWsdImport = true;
            yieldPatch('Wsd$objectName.$propertyName', node.offset, node.end);
          }
        }

        final parent = node.parent;
        // Check for non-namespaced `ButtonColor.wsd...` usage.
        yieldWsdRenamePatchIfApplicable(node, prefix?.name, identifier?.name);
        // Check for namespaced `mui.ButtonColor.wsd...` usage.
        if (node is PrefixedIdentifier && parent is PropertyAccess) {
          yieldWsdRenamePatchIfApplicable(
              parent, identifier?.name, parent.propertyName.name);
        }
      }

      // Add comments for components that need manual verification.
      if (identifier?.name == 'Badge' || identifier?.name == 'LinearProgress') {
        yieldInsertionPatch(
            lineComment(
                'FIXME(unify_package_rename) Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, manually QA this component and remove this FIXME; otherwise, migrate this component back to Web Skin Dart.'),
            node.offset);
      } else if (identifier?.name == 'Alert' ||
          identifier?.name == 'AlertPropsMixin') {
        yieldInsertionPatch(
            lineComment(
                'FIXME(unify_package_rename) Check what theme provider is wrapping this component: if it is a UnifyThemeProvider, update this to `${identifier?.name}` from `unify_ui/components/alert.dart`, manually QA this component, and remove this FIXME; otherwise, remove this FIXME.'),
            node.offset);
      }
    }
  }

  @override
  Future<void> generatePatches() async {
    _log.info('Resolving ${context.relativePath}...');

    final result = await context.getResolvedUnit();
    if (result == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    needsWsdImport = false;
    result.unit.visitChildren(this);

    if (needsWsdImport) {
      final insertInfo = insertionLocationForPackageImport(
          unifyWsdUri, result.unit, result.lineInfo);
      yieldPatch(
          insertInfo.leadingNewlines +
              "import '$unifyWsdUri';" +
              insertInfo.trailingNewlines,
          insertInfo.offset,
          insertInfo.offset);
    }
  }

  @override
  bool shouldSkip(FileContext context) => hasParseErrors(context.sourceText);
}
