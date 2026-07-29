#!/usr/bin/env node
/**
 * make_pck.mjs — Generic Godot 4.4 PCK builder.
 *
 * Walks a Godot project directory and packs all files into a valid .pck.
 * Supports both text and binary files (scripts, textures, models, audio).
 *
 * Usage: node make_pck.mjs <project_dir> <output.pck> [--patch-renderer]
 *
 * Options:
 *   --patch-renderer   Auto-replace Forward+ with gl_compatibility in project.godot
 */

import { writeFileSync, readFileSync, readdirSync, statSync } from 'fs';
import { createHash } from 'crypto';
import { join, relative } from 'path';

// ─── PCK format constants ─────────────────────────────────────────────────

const PACK_HEADER_MAGIC = 0x43504447; // "GDPC"
const PACK_FORMAT_VERSION = 2;
const VERSION_MAJOR = 4;
const VERSION_MINOR = 4;
const VERSION_PATCH = 0;
const ALIGNMENT = 32;

function pad(n, alignment) {
  const rest = n % alignment;
  return rest > 0 ? alignment - rest : 0;
}

function md5(data) {
  return createHash('md5').update(data).digest();
}

// ─── Directory walker ─────────────────────────────────────────────────────

const SKIP_DIRS = new Set(['.git', '__pycache__', 'node_modules', 'vector']);
// Inside .godot/, only include 'imported' subdirectory
const GODOT_INCLUDE_SUBDIRS = new Set(['imported']);
const SKIP_EXTENSIONS = new Set(['.md5', '.tmp', '.swp', '.uid']);
const SKIP_FILES = new Set(['.gitignore', '.gitattributes', '.gdignore', 'README.md', 'LICENSE.md']);

function walkDir(dir, baseDir, insideGodotDir = false) {
  const results = [];
  for (const entry of readdirSync(dir)) {
    const fullPath = join(dir, entry);
    const st = statSync(fullPath);
    if (st.isDirectory()) {
      if (SKIP_DIRS.has(entry)) continue;
      if (entry === '.godot') {
        // Enter .godot but only recurse into allowed subdirs
        results.push(...walkDir(fullPath, baseDir, true));
      } else if (insideGodotDir) {
        // Inside .godot/ — only recurse into 'imported'
        if (GODOT_INCLUDE_SUBDIRS.has(entry)) {
          results.push(...walkDir(fullPath, baseDir, false));
        }
      } else {
        results.push(...walkDir(fullPath, baseDir, false));
      }
    } else {
      if (SKIP_FILES.has(entry)) continue;
      const ext = entry.substring(entry.lastIndexOf('.'));
      if (SKIP_EXTENSIONS.has(ext)) continue;
      const relPath = relative(baseDir, fullPath).replace(/\\/g, '/');
      results.push({
        path: `res://${relPath}`,
        data: readFileSync(fullPath),
      });
    }
  }
  return results;
}

// ─── Parse args ───────────────────────────────────────────────────────────

const args = process.argv.slice(2);
const patchRenderer = args.includes('--patch-renderer');
const positional = args.filter(a => !a.startsWith('--'));

if (positional.length < 2) {
  console.error('Usage: node make_pck.mjs <project_dir> <output.pck> [--patch-renderer]');
  process.exit(1);
}

const [projectDir, outputPath] = positional;

// ─── Collect files ────────────────────────────────────────────────────────

console.log(`Scanning ${projectDir}...`);
const fileEntries = walkDir(projectDir, projectDir);

// Patch renderer if requested
if (patchRenderer) {
  const projEntry = fileEntries.find(e => e.path === 'res://project.godot');
  if (projEntry) {
    let text = projEntry.data.toString('utf-8');
    if (text.includes('forward_plus') || text.includes('Forward Plus')) {
      text = text.replace(/renderer\/rendering_method\s*=\s*"forward_plus"/g,
                          'renderer/rendering_method="gl_compatibility"');
      text = text.replace(/"Forward Plus"/g, '"4.4"');
      projEntry.data = Buffer.from(text, 'utf-8');
      console.log('  Patched renderer → gl_compatibility');
    }
  }
}

console.log(`Found ${fileEntries.length} files`);

// ─── Build PCK ────────────────────────────────────────────────────────────

let dirSize = 4; // file_count
for (const entry of fileEntries) {
  const pathBytes = Buffer.from(entry.path, 'utf-8');
  const pathPad = pad(pathBytes.length, 4);
  dirSize += 4 + pathBytes.length + pathPad + 8 + 8 + 16 + 4;
}

const headerSize = 96;
const dirPad = pad(headerSize + dirSize, ALIGNMENT);
const filesBase = headerSize + dirSize + dirPad;

let dataOffset = 0;
const fileOffsets = [];
for (const entry of fileEntries) {
  fileOffsets.push(dataOffset);
  dataOffset += entry.data.length;
  dataOffset += pad(dataOffset, ALIGNMENT);
}

const totalSize = filesBase + dataOffset;
const buf = Buffer.alloc(totalSize);
let pos = 0;

function writeU32(val) { buf.writeUInt32LE(val, pos); pos += 4; }
function writeU64(val) { buf.writeBigUInt64LE(BigInt(val), pos); pos += 8; }
function writeBytes(data) { data.copy(buf, pos); pos += data.length; }
function writeZeros(n) { buf.fill(0, pos, pos + n); pos += n; }

// ── Header ──
writeU32(PACK_HEADER_MAGIC);
writeU32(PACK_FORMAT_VERSION);
writeU32(VERSION_MAJOR);
writeU32(VERSION_MINOR);
writeU32(VERSION_PATCH);
writeU32(0); // flags
writeU64(filesBase);
writeZeros(64); // 16 reserved u32s

// ── Directory ──
writeU32(fileEntries.length);

for (let i = 0; i < fileEntries.length; i++) {
  const entry = fileEntries[i];
  const pathBytes = Buffer.from(entry.path, 'utf-8');
  const pathPad = pad(pathBytes.length, 4);

  writeU32(pathBytes.length + pathPad);
  writeBytes(pathBytes);
  if (pathPad > 0) writeZeros(pathPad);

  writeU64(fileOffsets[i]);
  writeU64(entry.data.length);
  writeBytes(md5(entry.data));
  writeU32(0); // flags
}

const currentDirPad = pad(pos, ALIGNMENT);
if (currentDirPad > 0) writeZeros(currentDirPad);

if (pos !== filesBase) {
  console.error(`ERROR: pos=${pos} != filesBase=${filesBase}`);
  process.exit(1);
}

// ── File data ──
for (const entry of fileEntries) {
  writeBytes(entry.data);
  const dataPad = pad(pos, ALIGNMENT);
  if (dataPad > 0) writeZeros(dataPad);
}

writeFileSync(outputPath, buf.subarray(0, pos));
console.log(`Created ${outputPath} (${pos} bytes, ${fileEntries.length} files)`);

// Show largest files
const sorted = [...fileEntries].sort((a, b) => b.data.length - a.data.length);
const top = sorted.slice(0, 20);
for (const entry of top) {
  const sizeKB = (entry.data.length / 1024).toFixed(1);
  console.log(`  ${entry.path} (${sizeKB} KB)`);
}
if (sorted.length > 20) {
  console.log(`  ... and ${sorted.length - 20} more files`);
}
