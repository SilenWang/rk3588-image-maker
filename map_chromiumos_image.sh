#!/bin/bash
top=$(dirname $0)
pushd $top 2>&1 1>/dev/null
top=$(pwd)
img_dir="$top/Image"
chromeos_image=""
loopdev=$(sudo losetup -f)
newest_loader="v1.07.111"
default_uboot="uboot.img"
get_miniloader=false
board=""

declare -A LINK_MAP=(
  [inaugural]="v1.04.106"
  [fydetab_duo]="v1.06.111"
  [khadas-edge2]="v1.09.111"
)

declare -A UBOOT_MAP=(
  [inaugural]="uboot.img"
  [fydetab_duo]="uboot.img"
  [khadas-edge2]="edge2-uboot.img"
)

die() {
  echo $@
  exit 1
}

parse_options()
{
  while [ "$1" ]; do
    case "$1" in
      "--board"|"-b")
        board=$2
        [ -z ${LINK_MAP[$board]} ] && die "invalid board $board"
        shift
      ;;
    *)
      chromeos_image=$1
      ;;
    esac
    shift
  done

  [ ! -f "$chromeos_image" ] && die "Usage:$0 [chromiumos_image bin]"
}

[ -b "$loopdev" ] || die "no loop device found."

mount_loopdev() {
  local img=$1
  sudo losetup $loopdev $img || die "mount error."
  sleep 1
  sudo partx -d $loopdev 2>&1 >/dev/null || true
  sudo partx -a $loopdev 2>&1 >/dev/null || die "Error mount patitions of $loopdev"
  echo $loopdev
}

link_img() {
  local src=${loopdev}$1
  local target=${img_dir}/${2}.img
  echo "link:$src as $target"
  ln -sf $src $target
  sudo chmod 666 $src
}

link_miniloader() {
  for b in "${!LINK_MAP[@]}"; do
    [ -n $board ] && break;
    echo "check board:$b"

    if [ -n "$(echo $chromeos_image | grep $b)" ]; then
        board=$b
    fi
  done

  if [ -n "$board" ]; then
    echo "link miniloader: ${LINK_MAP[$board]}"
    ln -sf $top/rk3588-uboot-bin/rk3588_spl_loader_${LINK_MAP["$board"]}.bin $img_dir/MiniLoaderAll.bin
    get_miniloader=true
  fi

  if ! $get_miniloader; then
    echo "Use the newset loader: $newest_loader"
    ln -sf $top/rk3588-uboot-bin/rk3588_spl_loader_${newest_loader}.bin $img_dir/MiniLoaderAll.bin
  fi
}

link_uboot() {
  local get_uboot=false

  if [ -n "$board" ]; then
    echo "link uboot.img: ${UBOOT_MAP[$board]}"
    ln -sf $top/rk3588-uboot-bin/${UBOOT_MAP["$board"]} ${img_dir}/uboot.img
    get_uboot=true
  fi

  if ! $get_uboot; then
    echo "Use the default uboot: $default_uboot"
    ln -sf $top/rk3588-uboot-bin/${default_uboot} ${img_dir}/uboot.img
  fi
}

main() {
  parse_options "$@"
  mount_loopdev $chromeos_image
  link_img p1 STATE
  link_img p2 KERN-A
  link_img p3 ROOT-A
  link_img p8 OEM
  link_img p12 EFI-SYSTEM
  link_miniloader
  link_uboot
}

main "$@"
popd 2>&1 1>/dev/null
