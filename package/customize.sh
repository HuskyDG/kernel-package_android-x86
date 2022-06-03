#!/sbin/sh
SKIPUNZIP=1



unzip -o "$ZIPFILE" '*' -x customize.sh 'system/*' kernel -d "$TMPDIR" &>/dev/null
export TMPDIR
unshare -m sh "$TMPDIR/script.sh" "$@"
err_code="$?"
rm -rf "$TMPDIR/script.sh"

# clean up
rm -rf "$TMPDIR"

exit "$err_code"