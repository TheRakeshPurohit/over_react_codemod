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
import 'package:over_react_codemod/src/rmui_preparation_suggestors/constants.dart';

import 'constants.dart';

/// Suggestor that updates the [existingScriptPath] <script> line to [newScriptPath] and
/// adds `type="module"` attribute to the script tag in a Dart string literal or list of string literals.
///
/// Meant to be run on Dart files (use [HtmlScriptAdder] to run on HTML files).
class DartScriptUpdater extends RecursiveAstVisitor<void>
    with AstVisitingSuggestor {
  final String existingScriptPath;
  final String newScriptPath;

  /// Whether or not to update attributes on script/link tags (like type/crossorigin)
  /// while also updating the script path.
  final bool updateAttributes;
  final bool removeTag;

  DartScriptUpdater(this.existingScriptPath, this.newScriptPath,
      {this.updateAttributes = true})
      : removeTag = false;

  /// Use this constructor to remove the whole tag instead of updating it.
  DartScriptUpdater.remove(this.existingScriptPath)
      : removeTag = true,
        updateAttributes = false,
        newScriptPath = 'will be ignored';

  @override
  void visitSimpleStringLiteral(SimpleStringLiteral node) {
    // This value includes the quotation marks.
    final stringValue = node.literal.lexeme;

    final relevantScriptTags = [
      ...Script(pathSubpattern: existingScriptPath)
          .pattern
          .allMatches(stringValue),
      ...?(!removeTag
          ? Script(pathSubpattern: newScriptPath)
              .pattern
              .allMatches(stringValue)
          : null)
    ];
    final relevantLinkTags = [
      ...Link(pathSubpattern: existingScriptPath)
          .pattern
          .allMatches(stringValue),
      ...?(!removeTag
          ? Link(pathSubpattern: newScriptPath).pattern.allMatches(stringValue)
          : null)
    ];

    // Do not update if neither the existingScriptPath nor newScriptPath are in the file.
    if (relevantScriptTags.isEmpty && relevantLinkTags.isEmpty) return;

    if (removeTag) {
      for (final tag in [...relevantScriptTags, ...relevantLinkTags]) {
        final tagEnd = node.offset + tag.end;
        final tagStart = node.offset + tag.start;
        final possibleCommaEnd = node.literal.next.toString() == ',' ? 1 : 0;
        final isTagSameAsNode =
            // Check if the only difference between [tag] and [node] is the quotes around [node].
            tagStart - node.offset <= 1 && node.end - tagEnd <= 1;

        yieldPatch(
          '',
          // If [tag] spans the whole string literal in [node], then also include
          // the quotes and comma in the removal.
          isTagSameAsNode
              // Remove from the end of the previous token to take any preceding newline with it,
              // so that we don't leave behind an empty line.
              ? node.beginToken.previous?.end ?? node.offset
              : tagStart,
          isTagSameAsNode ? (node.end + possibleCommaEnd) : tagEnd,
        );
      }
      return;
    }

    if (updateAttributes) {
      // Add type="module" attribute to script tag.
      for (final scriptTagMatch in relevantScriptTags) {
        final scriptTag = scriptTagMatch.group(0);
        if (scriptTag == null) continue;
        final typeAttributes =
            getAttributePattern('type').allMatches(scriptTag);
        if (typeAttributes.isNotEmpty) {
          final attribute = typeAttributes.first;
          final value = attribute.group(1);
          if (value == 'module') {
            continue;
          } else {
            // If the value of the type attribute is not "module", overwrite it.
            yieldPatch(
              typeModuleAttribute,
              node.offset + scriptTagMatch.start + attribute.start,
              node.offset + scriptTagMatch.start + attribute.end,
            );
          }
        } else {
          // If the type attribute does not exist, add it.
          final srcAttribute = getAttributePattern('src').allMatches(scriptTag);
          yieldPatch(
            ' ${typeModuleAttribute}',
            node.offset + scriptTagMatch.start + srcAttribute.first.end,
            node.offset + scriptTagMatch.start + srcAttribute.first.end,
          );
        }
      }

      // Add crossorigin="" attribute to link tag.
      for (final linkTagMatch in relevantLinkTags) {
        final linkTag = linkTagMatch.group(0);
        if (linkTag == null) continue;
        final crossOriginAttributes =
            getAttributePattern('crossorigin').allMatches(linkTag);
        if (crossOriginAttributes.isNotEmpty) {
          final attribute = crossOriginAttributes.first;
          final value = attribute.group(1);
          if (value == '') {
            continue;
          } else {
            // If the value of the crossorigin attribute is not "", overwrite it.
            yieldPatch(
              crossOriginAttribute,
              node.offset + linkTagMatch.start + attribute.start,
              node.offset + linkTagMatch.start + attribute.end,
            );
          }
        } else {
          // If the crossorigin attribute does not exist, add it.
          final hrefAttribute = getAttributePattern('href').allMatches(linkTag);
          yieldPatch(
            ' ${crossOriginAttribute}',
            node.offset + linkTagMatch.start + hrefAttribute.first.end,
            node.offset + linkTagMatch.start + hrefAttribute.first.end,
          );
        }
      }
    }

    // Update existing path to new path.
    final scriptMatches = existingScriptPath.allMatches(stringValue);
    scriptMatches.forEach((match) async {
      yieldPatch(
        newScriptPath,
        node.offset + match.start,
        node.offset + match.end,
      );
    });
  }
}
