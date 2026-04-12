import { window, Position, Range } from "vscode";

/**
 * Result of finding the most recent unclosed tag: its name and
 * the indentation of the line where the opening tag appears.
 */
interface UnclosedTag {
  name: string;
  indent: string;
}

/**
 * Find the most recent unclosed XML tag before the cursor position,
 * along with the indentation of the line containing the opening tag.
 *
 * Uses a stack-based scan: opening tags are pushed (with their
 * offset in the text), closing tags pop the matching opener.
 * After processing all tags before the cursor, the top of the stack
 * is the nearest unclosed tag.  Self-closing tags (e.g. `<idx/>`)
 * are excluded by the regex.
 *
 * Adapted from `getCurrentTag()` in @pretextbook/completions
 * (packages/completions/src/utils.ts).
 */
function findUnclosedTag(
  text: string,
  position: { line: number; character: number },
): UnclosedTag | undefined {
  const lines = text.split(/\r?\n/);
  const beforeCursor =
    lines.slice(0, position.line).join("\n") +
    (position.line > 0 ? "\n" : "") +
    (lines[position.line] || "").slice(0, position.character);

  // Match opening tags (excluding self-closing) and closing tags,
  // capturing the offset so we can look up indentation later.
  const tagPattern = /<(\w)+(?![^>]*\/>)|<\/\w+/g;
  const matches: { name: string; offset: number }[] = [];
  let m: RegExpExecArray | null;
  while ((m = tagPattern.exec(beforeCursor)) !== null) {
    matches.push({ name: m[0].slice(1), offset: m.index });
  }

  // Walk the matches with a stack, tracking the offset of each opener.
  const openTagStack: { name: string; offset: number }[] = [];
  for (const tag of matches) {
    if (tag.name.startsWith("/")) {
      const lastOpenTag = openTagStack.pop();
      if (lastOpenTag && lastOpenTag.name !== tag.name.slice(1)) {
        continue;
      }
    } else {
      openTagStack.push(tag);
    }
  }

  const unclosed = openTagStack.pop();
  if (!unclosed) {
    return undefined;
  }

  // Find the indentation of the line containing the opening tag.
  // Count backwards from the offset to find the start of the line,
  // then extract leading whitespace.
  let lineStart = unclosed.offset;
  while (lineStart > 0 && beforeCursor[lineStart - 1] !== "\n") {
    lineStart--;
  }
  const lineText = beforeCursor.slice(lineStart);
  const indentMatch = lineText.match(/^(\s*)/);
  const indent = indentMatch ? indentMatch[1] : "";

  return { name: unclosed.name, indent };
}

/**
 * Emacs nxml-mode style "close most recent unclosed tag" command.
 *
 * Bound to `ctrl+c /` (a chord keybinding that works naturally with
 * the Awesome Emacs Keymap extension, where `ctrl+c` is already the
 * Emacs C-c prefix key).
 *
 * 1. Scans backward from cursor to find the nearest unclosed opening tag
 * 2. Inserts `</tagname>` on a new line at the opening tag's indentation
 */
export async function cmdCloseTag() {
  const editor = window.activeTextEditor;
  if (!editor) {
    return;
  }

  const document = editor.document;
  const position = editor.selection.active;

  const unclosed = findUnclosedTag(document.getText(), {
    line: position.line,
    character: position.character,
  });

  if (!unclosed) {
    window.showInformationMessage("No unclosed tag found.");
    return;
  }

  // Build the closing tag text.  If the cursor is already at the
  // start of an empty (whitespace-only) line, replace that line's
  // whitespace and insert the closing tag at the opening tag's
  // indentation level.  Otherwise insert a newline first.
  const currentLine = document.lineAt(position.line);
  const lineIsEmpty = currentLine.text.trim() === "";

  await editor.edit((editBuilder) => {
    if (lineIsEmpty) {
      // Replace the entire current line content (just whitespace)
      // with the properly-indented closing tag.
      const lineRange = new Range(
        new Position(position.line, 0),
        new Position(position.line, currentLine.text.length),
      );
      editBuilder.replace(lineRange, `${unclosed.indent}</${unclosed.name}>`);
    } else {
      // Cursor is on a line with content — insert a newline
      // followed by the indented closing tag.
      editBuilder.insert(position, `\n${unclosed.indent}</${unclosed.name}>`);
    }
  });
}
