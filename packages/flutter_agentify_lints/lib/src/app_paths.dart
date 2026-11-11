/// The path of [filePath] relative to its `lib` folder, with `/` separators,
/// or `null` when the file is not under a `lib` folder.
///
/// When the path has several `lib` folders, the last one wins.
String? libRelativePath(String filePath) {
  final normalized = filePath.replaceAll(r'\', '/');
  final index = normalized.lastIndexOf('/lib/');
  if (index < 0) return null;
  return normalized.substring(index + '/lib/'.length);
}
