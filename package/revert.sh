#!/system/bin/sh


ui_print "- Revert all magisk modifications"

MAGISKTMP="$(magisk --path)"
[ -z "$MAGISKTMP" ] && exit

MOUNT_LIST="$(for i in /system /vendor /product /system/etc; do
grep "^tmpfs" /proc/mounts | awk '{ print $2 }' | grep ^"$i"
done)"

for hide in $MOUNT_LIST; do
echo "    unmount: $hide"
( umount -l "$hide" ) &
done

sleep 0.05

MOUNT_LIST="$(grep ".magisk/block" /proc/mounts | awk '{ print $2 }' | grep -v "^$MAGISKTMP")"

for hide in $MOUNT_LIST; do
echo "    unmount: $hide"
( umount -l "$hide" ) &
done