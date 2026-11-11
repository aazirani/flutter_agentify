/// The first [max] UTF-16 units of [text] plus [suffix], never ending on half
/// a surrogate pair. Returns [text] unchanged when it already fits; a negative
/// [max] counts as 0.
String cutText(String text, int max, {String suffix = ''}) {
  if (text.length <= max) return text;
  var end = max < 0 ? 0 : max;
  if (end > 0 && (text.codeUnitAt(end - 1) & 0xFC00) == 0xD800) end--;
  return '${text.substring(0, end)}$suffix';
}
