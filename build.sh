#!/bin/bash
#
# Compile script for kernel
#

# Initialize flags for options
clean=false
local=false
oss_only=false

# Use getopt for parsing long and short options
while [[ $# -gt 0 ]]; do
  case "$1" in
    -c|--clean)
      clean=true
      shift
      ;;
    -l|--local)
      local=true
      shift
      ;;
    --oss-only)
      oss_only=true
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

SECONDS=0 # builtin bash timer

ZIPNAME="[KSU-NEXT]STRIX-sweet-revival-$(date '+%Y%m%d-%H%M').zip"

export ARCH=arm64
export KBUILD_BUILD_USER=vbajs
export KBUILD_BUILD_HOST=tbyool

if [ ! -d "$PWD/clang" ]; then
	wget "$(curl -s https://raw.githubusercontent.com/ZyCromerZ/Clang/main/Clang-main-link.txt)" -O "zyc-clang.tar.gz"
	mkdir clang && tar -xvf zyc-clang.tar.gz -C clang && rm -rf zyc-clang.tar.gz
else
	echo "Local clang dir found, will not download clang and using that instead"
fi

export PATH="$PWD/clang/bin/:$PATH"
export KBUILD_COMPILER_STRING="$($PWD/clang/bin/clang --version | head -n 1 | perl -pe 's/\(http.*?\)//gs' | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

if [ "$local" = true ]; then
	echo "Local build, disabling LTO and not cloning telegram.sh.."
	patch -p1 < local-build.patch
else
	git clone --depth=1 https://github.com/fabianonline/telegram.sh.git telegram
fi

if [ "$clean" = true ]; then
	rm -rf out
	echo "Cleaned output folder"
fi

echo -e "\nStarting compilation...\n"
make O=out ARCH=arm64 vendor/sweet_defconfig
make -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

kernel="out/arch/arm64/boot/Image.gz"
dtbo="out/arch/arm64/boot/dtbo.img"
dtb="out/arch/arm64/boot/dtb.img"

if [ ! -f "$kernel" ] || [ ! -f "$dtbo" ] || [ ! -f "$dtb" ]; then
	echo -e "\nCompilation failed!"
	exit 1
fi

if [ "$oss_only" = true ]; then
	echo -e "\nNot compiling MIUI dimensions..."
	echo -e "\nKernel compiled successfully! Zipping up...\n"
	if [ -d "$AK3_DIR" ]; then
		cp -r $AK3_DIR AnyKernel3
	else
		if ! git clone -q https://github.com/vbajs/AnyKernel3.git -b fiqri AnyKernel3; then
			echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
			exit 1
		fi
	fi
	cp $kernel AnyKernel3
	cp $dtbo AnyKernel3
	cp $dtb AnyKernel3
	cd AnyKernel3
	zip -r9 "../$ZIPNAME" * -x .git README.md
	cd ..
	rm -rf AnyKernel3
	if [ "$local" = true ]; then
		git restore arch/arm64/configs/vendor/sweet_defconfig
	else
		if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
		   head=$(git rev-parse --verify HEAD 2>/dev/null); then
		        HASH="$(echo $head | cut -c1-8)"
		fi
		./telegram/telegram -f $ZIPNAME -C "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) ! Latest commit: $HASH !!WARNING!! OSS Only build!"
	fi
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
	exit 0
fi

echo -e "\nCompiled Kernel + OSS dimensions, now compiling MIUI dimensions while dirty.."
mkdir ./out/arch/arm64/boot/oss/
cp $dtbo out/arch/arm64/boot/oss/dtbo.img
ossdtbo="out/arch/arm64/boot/oss/dtbo.img"
rm -rf $dtbo
patch -p1 < miui-dtbo.patch
make -j$(nproc --all) \
    O=out \
    ARCH=arm64 \
    LLVM=1 \
    LLVM_IAS=1 \
    CROSS_COMPILE=aarch64-linux-gnu- \
    CROSS_COMPILE_COMPAT=arm-linux-gnueabi-

if [ ! -f "$dtbo" ]; then
	echo -e "\nCompilation failed!"
	exit 1
fi

echo -e "\nKernel compiled successfully! Zipping up...\n"
mkdir ./out/arch/arm64/boot/miui/
cp $dtbo out/arch/arm64/boot/miui/dtbo.img
miuidtbo="out/arch/arm64/boot/miui/dtbo.img"

if [ -d "$AK3_DIR" ]; then
	cp -r $AK3_DIR AnyKernel3
else
	if ! git clone -q https://github.com/vbajs/AnyKernel3.git -b fiqri AnyKernel3; then
		echo -e "\nAnyKernel3 repo not found locally and couldn't clone from GitHub! Aborting..."
		exit 1
	fi
fi

# Modify anykernel.sh to replace device names
sed -i "s/device\.name1=.*/device.name1=sweet/" AnyKernel3/anykernel.sh
sed -i "s/device\.name2=.*/device.name2=sweetin/" AnyKernel3/anykernel.sh

cd AnyKernel3
git reset --hard a74cbbf53f97245f6441663cfa0bc58db39aee53
cd ..
cp $kernel AnyKernel3
cp $ossdtbo AnyKernel3/dtbo/oss
cp $miuidtbo AnyKernel3/dtbo/miui
cp $dtb AnyKernel3
cd AnyKernel3
zip -r9 "../$ZIPNAME" * -x .git README.md
cd ..
rm -rf AnyKernel3
git restore arch/arm64/boot/dts/qcom/dsi-panel-k6-38-0c-0a-fhd-dsc-video.dtsi
if [[ "$local" = true ]]; then
	git restore arch/arm64/configs/vendor/sweet_defconfig
fi
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
echo "Zip: $ZIPNAME"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	HASH="$(echo $head | cut -c1-8)"
fi

if [ "$local" = false ]; then
	./telegram/telegram -f $ZIPNAME -C "Completed in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) ! Latest commit: $HASH"
fi
