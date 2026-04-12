import { window } from "vscode";
import { lspFormatDocument } from "../lsp-client/main";

/**
 * Find the most recent unclosed XML tag before the cursor position.
 *
 * Uses a stack-based scan: opening tags are pushed, closing tags pop
 * the matching opener.  After processing all tags before the cursor,
 * the top of the stack is the nearest unclosed tag.  Self-closing
 * tags (e.g. `<idx/>`) are excluded by the regex.
 *
 * Adapted from `getCurrentTag()` in @pretextbook/completions
 * (packages/completions/src/utils.ts).
 */
function findUnclosedTag(
  text: string,
  position: { line: number; character: number },
): string | undefined {
  const lines = text.split(/\r?\n/);
  const beforeCursor =
    lines.slice(0, position.line).join("\n") +
    (position.line > 0 ? "\n" : "") +
    (lines[position.line] || "").slice(0, position.character);

  const allTags = (beforeCursor.match(/<(\w)+(?![^>]*\/>)|<\/\w+/g) || []).map(
    (tag) => tag.slice(1),
  );

  const openTagStack: string[] = [];
  for (const tag of allTags) {
    if (tag.startsWith("/")) {
      const lastOpenTag = openTagStack.pop();
      if (lastOpenTag !== tag.slice(1)) {
        continue;
      }
    } else {
      openTagStack.push(tag);
    }
  }

  return openTagStack.pop();
}

/**
 * Emacs nxml-mode style "close most recent unclosed tag" command.
 *
 * Bound to `ctrl+c /` (a chord keybinding that works naturally with
 * the Awesome Emacs Keymap extension, where `ctrl+c` is already the
 * Emacs C-c prefix key).
 *
 * 1. Scans backward from cursor to find the nearest unclosed opening tag
 * 2. Inserts `</tagname>` at the cursor position
 * 3. Runs the PreTeXt formatter to fix indentation
 */
export async function cmdCloseTag() {
  const editor = window.activeTextEditor;
  if (!editor) {
    return;
  }

  const document = editor.document;
  const position = editor.selection.active;

  const tag = findUnclosedTag(document.getText(), {
    line: position.line,
    character: position.character,
  });

  if (!tag) {
    window.showInformationMessage("No unclosed tag found.");
    return;
  }

  const closingTag = `</${tag}>`;
  await editor.edit((editBuilder) => {
    editBuilder.insert(position, closingTag);
  });

  // Format the document to fix indentation of the content
  // between the opening and closing tags.
  lspFormatDocument(editor);
}
