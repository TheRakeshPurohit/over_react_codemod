import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:over_react_codemod/src/dart3_suggestors/null_safety_prep/utils/hint_detection.dart';
import 'package:over_react_codemod/src/util.dart';
import 'package:over_react_codemod/src/util/component_usage.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:pub_semver/pub_semver.dart';

import '../../../util/class_suggestor.dart';
import '../analyzer_plugin_utils.dart';

/// A class shared by the suggestors that manage defaultProps/initialState.
abstract class ClassComponentRequiredFieldsMigrator<Assignment extends PropOrStateAssignment> extends RecursiveAstVisitor<void>
    with ClassSuggestor {
  final String relevantGetterName;
  final String relevantMethodName;
  final Version? sdkVersion;

  ClassComponentRequiredFieldsMigrator(this.relevantGetterName, this.relevantMethodName, [this.sdkVersion]);

  late ResolvedUnitResult result;
  final Set<DefaultedOrInitializedDeclaration> fieldData = {};

  void patchFieldDeclarations(List<FieldElement> Function(InterfaceElement) getAll, Iterable<Assignment> cascadedDefaultPropsOrInitialState, CascadeExpression node) {
    for (final field in cascadedDefaultPropsOrInitialState) {
      final isDefaultedToNull = field.node.rightHandSide.staticType!.isDartCoreNull;
      final fieldEl = (field.node.writeElement! as PropertyAccessorElement).variable as FieldElement;
      // Short circuit before looking up the variable if we've already added it
      if (fieldData.map((data) => data.id).contains(fieldEl.id)) continue;
      final propsOrStateElement = node.staticType.tryCast<InterfaceType>()?.element;
      if (propsOrStateElement == null) continue;
      final fieldDeclaration = _getFieldDeclaration(getAll, propsOrStateElement: propsOrStateElement, fieldName: fieldEl.name);

      fieldData.add(DefaultedOrInitializedDeclaration(fieldEl.id, fieldDeclaration, isDefaultedToNull));
    }

    fieldData.where((data) => !data.patchedDeclaration).forEach((data) {
      data.patch(yieldPatch, sdkVersion: sdkVersion);
    });
  }

  VariableDeclaration? _getFieldDeclaration(List<FieldElement> Function(InterfaceElement) getAll, {
    required InterfaceElement propsOrStateElement,
    required String fieldName
  }) {
    // For component1 boilerplate its possible that `fieldEl` won't be found using `lookUpVariable` below
    // since its `enclosingElement` will be the generated abstract mixin. So we'll use the provided `getAll` fn to
    // cross reference the return value with the `fieldName`to locate the actual prop/state field declaration we want to patch.
    final siblingFields = getAll(propsOrStateElement);
    final matchingField = siblingFields.singleWhereOrNull((element) => element.name == fieldName);
    if (matchingField == null) return null;

    // NOTE: result.unit will only work if the declaration of the field is in this file
    return lookUpVariable(matchingField, result.unit);
  }

  @override
  Future<void> generatePatches() async {
    final r = await context.getResolvedUnit();
    if (r == null) {
      throw Exception(
          'Could not get resolved result for "${context.relativePath}"');
    }
    result = r;
    final compilationUnit = r.unit;

    final accessors = <PropertyAccessorElement>[];
    final methods = <MethodElement>[];
    compilationUnit.declaredElement!.classes.forEach((c) {
      accessors.addAll(c.accessors.where((a) => a.name == relevantGetterName));
      methods.addAll(c.methods.where((m) => m.name == relevantMethodName));
    });

    // Short-circuit if there are no default props / initial state set in this unit
    if (accessors.isNotEmpty || methods.isNotEmpty) {
      r.unit.accept(this);
    }
  }
}

class DefaultedOrInitializedDeclaration {
  final int id;
  final VariableDeclaration? fieldDecl;
  final bool isDefaultedToNull;
  final String name;

  DefaultedOrInitializedDeclaration(this.id, this.fieldDecl, this.isDefaultedToNull)
      : _patchedDeclaration = false,
        name = '${fieldDecl?.name.value()}';

  /// Whether the declaration has been patched with the late / nullable hints.
  bool get patchedDeclaration => _patchedDeclaration;
  bool _patchedDeclaration;

  void patch(void Function(String updatedText, int startOffset, [int? endOffset]) handleYieldPatch, {Version? sdkVersion}) {
    if (fieldDecl == null) return;
    final type = (fieldDecl!.parent! as VariableDeclarationList).type;
    final fieldNameToken = fieldDecl!.name;
    String? late = type != null && requiredHintAlreadyExists(type) ? null : '/*late*/';
    String? nullability = '/*${isDefaultedToNull ? '?' : '!'}*/';
    if (sdkVersion != null && VersionRange(min: Version.parse('2.12.0')).allows(sdkVersion)) {
      if (late != null) {
        // If the repo has opted into null safety, patch with the real thing instead of hints
        late = 'late';
        // Unless it already has the late keyword applied
        if ((type?.parent as VariableDeclarationList?)?.lateKeyword is Token) {
          late = null;
        }
      }

      nullability = isDefaultedToNull ? '?' : '';
    }

    // Object added if type is null b/c we gotta have a type to add the nullable `?`/`!` hints to - even if for some reason the prop/state decl. has no left side type.
    handleYieldPatch('${late ?? ''} ${type == null ? 'Object' : type.toString()}$nullability ', type?.offset ?? fieldNameToken.offset, fieldNameToken.offset);

    _patchedDeclaration = true;
  }

  @override
  bool operator ==(Object other) {
    // Use the id of the `FieldElement` for equality so that the set created in ClassComponentRequiredDefaultPropsMigrator filters out dupe instances.
    return other is DefaultedOrInitializedDeclaration && other.id == this.id;
  }

  @override
  int get hashCode => this.id;
}