OUTFD="$2"
ZIPFILE="$3"
MAGISKTMP="$(magisk --path)"

. "$TMPDIR/util_functions.sh"

if [ "$BOOTMODE" == true ]; then
    [ ! -z "$MAGISKTMP" ] && export PATH="$MAGISKTMP/.magisk/busybox:$PATH"
fi

MODNAME=`grep_prop name $TMPDIR/module.prop`
MODVER=`grep_prop version $TMPDIR/module.prop`
MODAUTH=`grep_prop author $TMPDIR/module.prop`

print_title "$MODNAME" "$MODVER"
print_title "by $MODAUTH"

api_level_arch_detect
[ "$ABI32" != "x86" ] && abort "! This zip is only for Android x86"

CHECKROOT="$(mountpoint -d /)"


if [ "${CHECKROOT%:*}" == 0 ]; then
    system=/system
elif $BOOTMODE; then
    system=/
else
    mount /system
    mount /system_root
    system=/system_root
fi

get_oroot_var

# we must restore system partition to original overwise the installation would write to tmpfs overlay

test "$BOOTMODE" == "true" && . "$TMPDIR/revert.sh"

ui_print "- Mount system partition as read-write"
mount -o rw,remount $system || abort "! System partition is read-only"

# make sure system is truly read-write
is_rw=false
OLDIFS="$IFS"
IFS=$"\,"
for flag in `cat /proc/mounts | grep " $system " | awk '{ print $4 }' | tail -1`; do
    if [ "$flag" == rw ]; then
        is_rw=true
        break;
    fi
done
IFS="$OLDIFS"
test "$is_rw" == "false" && abort "! System partition is read-only"


chmod 777 "$TMPDIR/zip"

# backup original kernel package

( if [ ! -f "$OROOT/stock_kernel.zip" ]; then
    ui_print "- Backup original kernel"
    mkdir -p "$TMPDIR/stock_kernel/system/lib"
    unzip -o "$ZIPFILE" -x module.prop 'system/*' kernel -d "$TMPDIR/stock_kernel" >&2
    cat <<EOF >"$TMPDIR/stock_kernel/module.prop"
name=Stock Kernel
author=Android-x86
EOF
    cp -af /system/lib/modules/module.prop "$TMPDIR/stock_kernel/module.prop"
    cp -af "$OROOT/kernel" "$TMPDIR/stock_kernel/kernel"
    cd "$TMPDIR/stock_kernel"
    "$TMPDIR/zip" -9yr "$OROOT/stock_kernel.zip" $(ls .) /system/lib/firmware /system/lib/modules >&2
fi )



case "$?" in
    0)
        ui_print "- Original kernel package is $OROOT/stock_kernel.zip"
        ;;
    *)
        abort "! Cannot backup kernel"
        ;;
esac

ui_print "- Install kernel image"
cp "$OROOT/kernel" "$TMPDIR/kernel.old"
unzip -o "$ZIPFILE" kernel -d "$OROOT" >&2 || abort "! Failed to install kernel image"
ui_print "- Install firmware and kernel modules"

# backup previous firmware and modules so that we can restore if installation fails
mv -f /system/lib/firmware /system/lib/firmware.bak
mv -f /system/lib/modules /system/lib/modules.bak

unzip -o "$ZIPFILE" 'system/*' -d / >&2 || {

# install fails, restore everything
    rm -rf /system/lib/firmware /system/lib/modules
    mv -f /system/lib/firmware.bak /system/lib/firmware
    mv -f /system/lib/modules.bak /system/lib/modules
    mv -f "$TMPDIR/kernel.old" "$OROOT/kernel"
    abort "! Failed to install firmware and kernel modules"
}

cp -af "$TMPDIR/module.prop" /system/lib/modules/module.prop
chmod -R 755 /system/lib/firmware
chmod -R 755 /system/lib/modules

rm -rf /system/lib/firmware.bak /system/lib/modules.bak
ui_print "******************************"
ui_print " If you want to restore original kernel"
ui_print "  you can flash backup stock_kernel.zip"
ui_print "  which was saved to Android-x86 directory"
ui_print "******************************"
ui_print "- All done!"
true