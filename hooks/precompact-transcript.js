// Reads a Claude Code transcript (JSONL) and prints the last files touched and
// the last commands run. Called by the PreCompact hook.
//
// This is node rather than grep because every value in the transcript is a JSON
// string: a command containing \" truncates any `grep -o '"command":"[^"]*"'`
// at the first escape, and a Windows path arrives with every backslash doubled.
// Parsing the line is the only thing that gets both right.
const fs = require('fs');

const file = process.argv[2];
if (!file || !fs.existsSync(file)) process.exit(0);

const size = fs.statSync(file).size;
const start = Math.max(0, size - 4_000_000);
const fd = fs.openSync(file, 'r');
const buf = Buffer.alloc(size - start);
fs.readSync(fd, buf, 0, buf.length, start);
fs.closeSync(fd);

const files = [];
const commands = [];

const walk = (node) => {
  if (!node || typeof node !== 'object') return;
  if (Array.isArray(node)) return node.forEach(walk);
  if (node.type === 'tool_use' && node.input && typeof node.input === 'object') {
    const { file_path: fp, command: cmd } = node.input;
    if (typeof fp === 'string') files.push(fp);
    if (typeof cmd === 'string') commands.push(cmd.replace(/\s+/g, ' ').trim());
  }
  for (const v of Object.values(node)) walk(v);
};

// The first line is almost certainly cut in half by the offset. Dropping a
// parse failure is correct here - a truncated line has no complete tool call.
for (const line of buf.toString('utf8').split('\n')) {
  if (!line.trim()) continue;
  try { walk(JSON.parse(line)); } catch { /* partial line */ }
}

const lastUnique = (arr, n) => {
  const out = [];
  for (let i = arr.length - 1; i >= 0 && out.length < n; i--) {
    if (!out.includes(arr[i])) out.push(arr[i]);
  }
  return out.reverse();
};

const print = (title, rows) => {
  if (!rows.length) return;
  console.log('');
  console.log(`## ${title}`);
  console.log('');
  for (const r of rows) console.log('  ' + r.slice(0, 160));
};

print('Last files written or edited', lastUnique(files, 12));
print('Last commands run', lastUnique(commands, 8));
