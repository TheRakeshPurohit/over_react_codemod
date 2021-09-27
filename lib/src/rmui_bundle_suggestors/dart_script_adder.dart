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

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:codemod/codemod.dart';
import 'package:over_react_codemod/src/rmui_bundle_suggestors/html_script_adder.dart';
import 'package:over_react_codemod/src/util.dart';

import 'constants.dart';

/// Suggestor that adds a [scriptToAdd] line after the last usage of a
/// react-dart script in a Dart string literal or list of string literals.
///
/// Meant to be run on Dart files (use [HtmlScriptAdder] to run on HTML files).
class DartScriptAdder extends RecursiveAstVisitor with AstVisitingSuggestor {
  final String scriptToAdd;

  /// Whether or not [scriptToAdd] is for production.
  ///
  /// This will determine if the script should be added to React dev or React prod js files.
  final bool isProd;

  DartScriptAdder(this.scriptToAdd, this.isProd);

  @override
  visitSimpleStringLiteral(SimpleStringLiteral node) {
    // This value includes the quotation marks.
    final stringValue = node.literal.lexeme;
    final parent = node.parent;

    // Do not add the script if it already exists in the string.
    if (stringValue.contains(scriptToAdd)) return;

    if (parent is VariableDeclaration) {
      final scriptMatches =
          RegExp(reactJsScriptPattern).allMatches(stringValue);

      if (scriptMatches.isNotEmpty) {
        final lastMatch = scriptMatches.last;

        // Only add [scriptToAdd] if it has the same prod/dev status as the
        // react-dart js [lastMatch] found.
        final lastMatchValue = lastMatch.group(0)!;
        if (isProd != isScriptProd(lastMatchValue)) return;

        yieldPatch(
          // Add the new script with the same indentation as the line before it.
          '\n${lastMatch.group(1)}$scriptToAdd',
          // Add [scriptToAdd] right after the location of [lastMatch] within
          // the string literal [node].
          node.offset + lastMatch.end,
          node.offset + lastMatch.end,
        );
      }
    } else if (parent is ListLiteral) {
      // Do not add the script to the list if it is already there.
      if (parent.elements.any((element) =>
          element is SimpleStringLiteral &&
          element.literal.lexeme.contains(scriptToAdd))) return;

      // Verify [node.value] (without the quotes) is an exact match.
      final reactScriptRegex = RegExp('^$reactJsScriptPattern\$');
      final scriptMatch = reactScriptRegex.firstMatch(node.value);

      if (scriptMatch != null) {
        // To avoid adding the [scriptToAdd] twice, verify that [node] is the
        // last matching react script in the list.
        final lastMatchElement = parent.elements.lastWhere((element) =>
            element is SimpleStringLiteral &&
            reactScriptRegex.firstMatch(element.value) != null);
        if (node.offset != lastMatchElement.offset) return;

        // Only add [scriptToAdd] if it has the same prod/dev status as the
        // react-dart js [scriptMatch] found.
        final scriptMatchValue = scriptMatch.group(0)!;
        if (isProd != isScriptProd(scriptMatchValue)) return;

        yieldPatch(
          // Add the new script to the list.
          ',\n\'$scriptToAdd\'',
          node.end,
          node.end,
        );
      }
    }
  }

  @override
  bool shouldSkip(FileContext context) => hasParseErrors(context.sourceText);
}
