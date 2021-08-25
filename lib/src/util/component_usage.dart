// This file is based on over_react_analyzer_plugins's FluentComponentUsage
// TODO consolidate these into a single library; perhaps in over_react?

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:meta/meta.dart';
import 'package:over_react_codemod/src/util/range_factory.dart';
import 'package:over_react_codemod/src/element_type_helpers.dart';
export 'package:over_react_codemod/src/fluent_interface_util/cascade_read.dart';

/// A usage of an OverReact component via its fluent interface.
class FluentComponentUsage {
  FluentComponentUsage._(this.node, this.cascadeExpression, this.builder);

  /// The top-level node of this usage.
  final InvocationExpression node;

  /// The cascade of this usage (unwrapped from parens), or `null` if it doesn't have one.
  final CascadeExpression? cascadeExpression;

  /// The expression upon which the cascade is performed,
  /// and that is invoked with children to build the component.
  ///
  /// E.g., `Dom.div()`, `Button()`, `builder`
  ///
  /// Usually a [MethodInvocation] or [Identifier].
  final Expression builder;

  Expression? get factory => builder.tryCast<InvocationExpression>()?.function;

  String? get componentName => getComponentName(builder);

  bool get isDom => const ['DomProps', 'SvgProps']
      .contains(builder.staticType?.interfaceTypeName);
  bool get isSvg =>
      const ['SvgProps'].contains(builder.staticType?.interfaceTypeName);

  /// Whether the invocation contains one or more children passed as arguments instead of a list.
  bool get hasVariadicChildren =>
      node.argumentList.arguments.isNotEmpty &&
      node.argumentList.arguments.first is! ListLiteral;

  /// The number of child arguments passed into the invocation.
  int get childArgumentCount => node.argumentList.arguments.length;
}

PropAssignment? getPropAssignment(AssignmentExpression node) {
  final lhs = node.leftHandSide;
  // fixme cleanup move into factory
  if (lhs is! PropertyAccess && lhs is! PrefixedIdentifier) {
    return null;
  }

  final assignment = PropAssignment(node);
  if (assignment.target.staticType?.isPropsClass ?? false) {
    return assignment;
  }

  return null;
}

//
// class Foo {
//   var bar;
// }
// // fixme document this
// main() {
//   Foo foo = Foo(XZ);
//
//   // AssignmentExpressionImpl PrefixedIdentifierImpl
//   foo.bar = '';
//   // AssignmentExpressionImpl PropertyAccessImpl
//   foo?.bar = '';
//   // CascadeExpressionImpl AssignmentExpressionImpl PropertyAccessImpl
//   foo..bar = '';
// }

// Fixme write hella test cases for this, including `.aria.label`
// TODO what about indexed prop assignments?
abstract class PropAssignment {
  factory PropAssignment(AssignmentExpression node) {
    if (node.leftHandSide is PropertyAccess) {
      return _PropertyAccessPropAssignment(node);
    } else if (node.leftHandSide is PrefixedIdentifier) {
      return _PrefixedIdentifierPropAssignment(node);
    } else {
      throw ArgumentError.value(
        node.leftHandSide,
        'node.leftHandSide',
        'Unhandled LHS node type',
      );
    }
  }

  /// The object on which a property is being assigned
  ///
  /// (e.g., a factory invocation expression, a builder variable)
  Expression get target;

  /// The name of the prop being assigned.
  Identifier get name;

  /// The cascaded assignment expression that backs this assignment.
  AssignmentExpression get assignment;

  /// The property access representing the left hand side of this assignment.
  Expression get leftHandSide => assignment.leftHandSide;

  /// The expression for the right hand side of this assignment.
  Expression get rightHandSide => assignment.rightHandSide;

  //
  // /// The "target" of the [name].
  // ///
  // /// For example, the value of `targetName.name` in the expression below is "aria":
  // ///
  // /// ```dart
  // /// ..aria.label = 'foo'
  // /// ```
  // Identifier? get targetName => leftHandSide.tryCast<PropertyAccess>()?.target?.tryCast<PropertyAccess>()?.propertyName;

  /// A range that can be used in a `builder.addDeletion` call to remove this prop.
  ///
  /// Includes the space between the previous token and the start of this assignment, so that
  /// the entire prop line is removed.
  ///
  /// __Note: prefer using [removeProp] instead of using this directly to perform removals__
  @protected
  SourceRange get rangeForRemoval => range.node(assignment);

  bool get isInCascade;

  CascadeExpression? get parentCascade;
}

class _PropertyAccessPropAssignment with PropAssignment {
  /// The cascaded assignment expression that backs this assignment.
  @override
  final AssignmentExpression assignment;

  _PropertyAccessPropAssignment(this.assignment)
      : assert(assignment.leftHandSide is PropertyAccess);

  /// The property access representing the left hand side of this assignment.
  @override
  PropertyAccess get leftHandSide => assignment.leftHandSide as PropertyAccess;

  @override
  Identifier get name => leftHandSide.propertyName;

  @override
  Expression get target => leftHandSide.realTarget;

  @override
  bool get isInCascade => parentCascade != null;

  // Fixme is this implementation correct / overly defensive?
  // final cascade = assignment
  //       .thisOrAncestorOfType<CascadeExpression>();
  //
  // if (cascade?.cascadeSections.contains(assignment.leftHandSide) ?? false) {
  //   return cascade;
  // }
  @override
  CascadeExpression? get parentCascade => assignment.parent.tryCast();
}

class _PrefixedIdentifierPropAssignment with PropAssignment {
  /// The cascaded assignment expression that backs this assignment.
  @override
  final AssignmentExpression assignment;

  _PrefixedIdentifierPropAssignment(this.assignment)
      : assert(assignment.leftHandSide is PrefixedIdentifier);

  /// The property access representing the left hand side of this assignment.
  @override
  PrefixedIdentifier get leftHandSide =>
      assignment.leftHandSide as PrefixedIdentifier;

  @override
  Identifier get name => leftHandSide.identifier;

  @override
  Expression get target => leftHandSide.prefix;

  // Fixme is this implementation correct?
  @override
  bool get isInCascade => false;

  @override
  get parentCascade => null;
}

class IndexPropAssignment {
  /// The cascaded assignment expression that backs this assignment.
  final AssignmentExpression assignment;

  IndexPropAssignment(this.assignment) {
    if (assignment.leftHandSide is! IndexExpression) {
      throw ArgumentError.value(
        assignment.leftHandSide,
        'node.leftHandSide',
        'Must be an IndexExpreesion',
      );
    }
  }

  /// The property access representing the left hand side of this assignment.
  IndexExpression get leftHandSide =>
      assignment.leftHandSide as IndexExpression;

  Expression get index => leftHandSide.index;

  /// The expression for the right hand side of this assignment.
  Expression get rightHandSide => assignment.rightHandSide;
}

extension _TryCast<T> on T {
  S? tryCast<S extends T>() {
    final self = this;
    return self is S ? self : null;
  }
}

extension on DartType? {
  String? get interfaceTypeName => tryCast<InterfaceType>()?.element.name;
}

/// Returns the OverReact fluent interface component for the invocation expression [node],
/// or `null` if it doesn't represent one.
///
/// Fluent interface usages that are detected:
///
/// * `Dom.*()`, optionally namespaced with a named import
///     * e.g., `Dom.h1()`, `over_react.Dom.h1()`
/// * Capitalized factory invocations, optionally namespaced with a named import
///     * e.g., `Foo()`, `bar_library.Foo()`
/// * `*Factory*()`
///     * e.g., `customButtonFactory()`
/// * `*Builder*()`
///     * e.g., `getButtonBuilder()`
/// * `*builder*`
///     * e.g., `var buttonBuilder = Button();`
FluentComponentUsage? getComponentUsage(InvocationExpression node) {
  var functionExpression = node.function;

  Expression builder;
  CascadeExpression? cascadeExpression;

  if (functionExpression is ParenthesizedExpression) {
    var expression = functionExpression.expression;
    if (expression is CascadeExpression) {
      cascadeExpression = expression;
      builder = expression.target;
    } else {
      builder = expression;
    }
  } else {
    builder = functionExpression;
  }

  bool isComponent;
  if (builder.staticType != null) {
    // Resolved AST
    isComponent =
        builder.staticType.interfaceTypeName?.endsWith('Props') ?? false;
  } else {
    // Unresolved AST (or type wasn't available)
    isComponent = false;

    if (builder is MethodInvocation) {
      String? builderName = getComponentName(builder);

      if (builderName != null) {
        isComponent =
            RegExp(r'(?:^|\.)Dom\.[a-z0-9]+$').hasMatch(builderName) ||
                RegExp(r'factory|builder', caseSensitive: false)
                    .hasMatch(builderName) ||
                RegExp(r'(?:^|\.)[A-Z][^\.]*$').hasMatch(builderName);
      }
    } else if (builder is Identifier) {
      isComponent =
          RegExp(r'builder', caseSensitive: false).hasMatch(builder.name);
    }
  }

  if (!isComponent) return null;

  return FluentComponentUsage._(node, cascadeExpression, builder);
}

String? getComponentName(Expression builder) {
  if (builder.staticType != null) {
    // Resolved AST
    final typeName = builder.staticType?.interfaceTypeName;
    if (typeName == null) return null;
    if (const ['dynamic', 'UiProps'].contains(typeName)) return null;
    if (builder is MethodInvocation) {
      return builder.methodName.name;
    }
    if (typeName.endsWith('Props')) {
      // Some props classes have an extra "Component" part in their name.
      return typeName.replaceFirst(r'(Component)?Props$', '');
    }
    return null;
  } else if (builder is MethodInvocation) {
    // Unresolved
    String builderName;
    if (builder.target != null) {
      builderName = builder.target!.toSource() + '.' + builder.methodName.name;
    } else {
      builderName = builder.methodName.name;
    }
    return builderName;
  }
  return null;
}

/// A visitor that detects whether a given node is a [FluentComponentUsage].
class ComponentDetector extends SimpleAstVisitor<void> {
  bool detected = false;

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    return visitInvocationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    return visitInvocationExpression(node);
  }

  @override
  void visitParenthesizedExpression(ParenthesizedExpression node) {
    // Recursively traverse parentheses, in case there are extra parens on the component.
    node.visitChildren(this);

    return null;
  }

  void visitInvocationExpression(InvocationExpression node) {
    if (getComponentUsage(node) != null) {
      detected = true;
    }

    return null;
  }
}

/// Returns whether there is an OverReact component usage within [arguments].
///
/// Usages that aren't directly arguments (nested within other structures) are not detected.
bool hasChildComponent(ArgumentList arguments) {
  var detector = ComponentDetector();
  arguments.visitChildren(detector);

  return detector.detected;
}

/// Attempt to find and return the closest expression that encloses the [node]
/// and is an independent Flutter `Widget`.  Return `null` if nothing found.
FluentComponentUsage? identifyUsage(AstNode? node) {
  for (; node != null; node = node.parent) {
    if (node is InvocationExpression) {
      final usage = getComponentUsage(node);
      if (usage != null) {
        return usage;
      }
    }
    if (node is ArgumentList || node is Statement || node is FunctionBody) {
      return null;
    }
  }
  return null;
}

class ComponentUsageVisitor extends RecursiveAstVisitor<void> {
  ComponentUsageVisitor(this.onComponent);

  final void Function(FluentComponentUsage) onComponent;

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    visitInvocationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    visitInvocationExpression(node);
  }

  void visitInvocationExpression(InvocationExpression node) {
    var usage = getComponentUsage(node);
    if (usage != null) {
      onComponent(usage);
    }

    node.visitChildren(this);
  }
}
