#!/bin/bash

cyan='tput setaf 6'
yellow='tput setaf 3'
reset='tput sgr0'

validate_arg() {
    valid=$(echo $1 | sed s'/^[\-][a-z0-9A-Z\-]*/valid/'g)
    [ "x$1" == "x$0" ] && return 0;
    [ "x$1" == "x" ] && return 0;
    [ "$valid" == "valid" ] && return 0 || return 1;
}

print_help() {
    echo "Usage: `basename $0` [OPTION]";
    echo "  -i, --init-source \ Init source, current supported roms rr,pe,pe-caf" ;
    echo "  -s, --sync-android \ Sync current source" ;
    echo "  -b, --brand \ Brand name" ;
    echo "  -d, --device \ Device name" ;
    echo "  -dt --device-tree \ Specify Device Tree for unofficial build" ;
    echo "  -t, --target \ Make target" ;
    echo "  -c, --clean \ Clean target" ;
    echo "  -ca, --cleanall \ Clean entire out" ;
    echo "  -tg, --telegram \ Enable telegram message" ;
    echo "  -u, --upload \ Enable drive upload" ;
    echo "  -r, --Release \ Enable drive upload, tg msg and clean" ;
    exit
}

prev_arg=
while [ "$1" != "" ]; do
    cur_arg=$1

    # find arguments of the form --arg=val and split to --arg val
    if [ -n "`echo $cur_arg | grep -o =`" ]; then
        cur_arg=`echo $1 | cut -d'=' -f 1`
        next_arg=`echo $1 | cut -d'=' -f 2`
    else
        cur_arg=$1
        next_arg=$2
    fi

    case $cur_arg in

        -i | --init-source )
            prepare_source_scr=$next_arg
            ;;
        -U | --url )
            repo_init_url=$next_arg
            ;;
        -b | --branch )
            repo_branch=$next_arg
            ;;
        -s | --sync-android )
            sync_android_scr=1
            ;;
        -b | --brand )
            brand_scr=$next_arg
            export brand_scr
            ;;
        -d | --device )
            device_scr=$next_arg
            export device_scr
            ;;
        -t | --target )
            build_type_scr=$next_arg
            build_orig_scr=$next_arg
            ;;
        -tg | --telegram )
            telegram_scr=1
            ;;
        -u | --upload )
            upload_scr=1
            ;;
        -dt | --device-tree )
            device_tree=$next_arg
            ;;

        -r | --release )
            telegram_scr=1
            upload_scr=1
            clean_scr=1
            ;;
        -c | --clean )
            clean_scr=1
            ;;
        -ca | --clean-all )
            cleanall_scr=1
            ;;
        *)
            validate_arg $cur_arg;
            if [ $? -eq 0 ]; then
                echo "Unrecognised option $cur_arg passed"
                print_help
            else
                validate_arg $prev_arg
                if [ $? -eq 1 ]; then
                    echo "Argument $cur_arg passed without flag option"
                    print_help
                fi
            fi
            ;;
    esac
    prev_arg=$1
    shift
done

acquire_build_lock() {

    lock_name="android_build_lock"
    lock="$HOME/${lock_name}"

    exec 200>${lock}

    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Attempting to acquire lock $($yellow)$lock$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)

    # loop if we can't get the lock
    while true; do
        flock -n 200
        if [ $? -eq 0 ]; then
            break
        else
            printf "%c" "."
            sleep 5
        fi
    done

    # set the pid
    pid=$$
    echo ${pid} 1>&200

    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Lock $($yellow)${lock}$($cyan) acquired. PID is $($yellow)${pid}$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)
}

remove_build_lock() {
    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Removing $($yellow)$lock$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)
    exec 200>&-
}

prepare_source() {

    printf "%s\n\n" $($cyan)
    printf "%s\n" "**************************"
    printf '%s\n' "Initializing $($yellow)$prepare_source_scr$($cyan)"
    printf "%s\n" "**************************"
    printf "%s\n\n" $($reset)
    source_android_scr=$prepare_source_scr
    repo init -u $repo_init_url -b $repo_branch
    if [ $device_tree ]; then
      printf "%s\n\n" $($cyan)
      printf "%s\n" "**************************"
      printf '%s\n' "Unofficial Device Tree Detected"
      printf "%s\n" "**************************"
      printf "%s\n\n" $($reset)
      git clone $device_tree device/$brand/$device
      python3 unofficial_builder.py
    fi
    ##### if this fails idc, its your problem biatch
}

function_check() {
    if [ ! $TELEGRAM_TOKEN ] && [ ! $TELEGRAM_CHAT ] && [ ! $G_FOLDER ]; then
        printf "You don't have TELEGRAM_TOKEN,TELEGRAM_CHAT,G_FOLDER set"
        exit
    fi


    if [ ! -f telegram ];
    then
        echo "Telegram binary not present. Installing.."
        wget -q https://raw.githubusercontent.com/Dyneteve/misc/master/telegram
        chmod +x telegram
    fi

    if [ ! -d $HOME/buildscript ];
    then
        mkdir $HOME/buildscript
    fi
}

sync_source() {
    if [ $sync_android_scr ]; then
        repo sync -j$(nproc) --force-sync --no-tags --no-clone-bundle -c
    fi
}

start_env() {
    rm -rf venv
    virtualenv2 venv
    source venv/bin/activate
}

setup_paths() {
    source build/envsetup.sh
    export USE_CCACHE=1

    if [ $prepare_source_scr ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "*********************************************"
        printf '%s\n' "Attempting to sync device trees from rom repo"
        printf "%s\n" "*********************************************"
        printf "%s\n\n" $($reset)
        lunch "$sync_tree_scr"_"$device_scr"-userdebug
    fi

    OUT_SCR=out/target/product/$device_scr
    DEVICEPATH_SCR=device/$brand_scr/$device_scr

    if [ $prepare_source_scr ] && [ ! -d $DEVICEPATH_SCR ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "**********************************"
        printf '%s\n' "Syncing tree from rom repo failed"
        printf "%s\n" "**********************************"
        printf "%s\n\n" $($reset)
        exit
    fi

    if [ -z "$build_type_scr" ]; then
        build_type_scr=bacon
    fi
}

clean_target() {
    if [ $clean_scr ] && [ ! $cleanall_scr ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "**************************"
        printf '%s\n' "Cleaning target $($yellow) $device_scr $($cyan)"
        printf "%s\n" "**************************"
        printf "%s\n\n" $($reset)
        rm -rf $OUT_SCR
        sleep 2
    elif [ $cleanall_scr ]; then
        printf "%s\n\n" $($cyan)
        printf "%s\n" "**************************"
        printf '%s\n' "Cleaning entire out"
        printf "%s\n" "**************************"
        printf "%s\n\n" $($reset)
        rm -rf out
        sleep 2s
    fi
}

upload() {

    if [ $telegram_scr ] && [ ! $(grep -c "#### build completed successfully" build.log) -eq 1 ]; then
        bash telegram -D -M "
        *Build for $device_scr failed!*"
        bash telegram -f build.log
        exit
    fi

    case $build_type_scr in
        bacon)
            file=$(ls $OUT_SCR/*201*.zip | tail -n 1)
            ;;
        bootimage)
            file=$OUT_SCR/boot.img
            ;;
        recoveryimage)
            file=$OUT_SCR/recovery.img
            ;;
        dtbo)
            file=$OUT_SCR/dtbo.img
            ;;
        systemimage)
            file=$OUT_SCR/system.imgHow to get parameter of next one
            ;;
        vendorimage)
            file=$OUT_SCR/vendor.img
    esac

    if [ -f $HOME/buildscript/*.img ]; then
        rm -f $HOME/buildscript/*.img
    fi
How to get parameter of next one
    build_date_scr=$(date +%F_%H-%M)
    if [ ! -z $build_orig_scr ] && [ $upload_scr ]; then
        cp $file $HOME/buildscript/"$build_type_scr"-"$build_date_scr".img
        file=`ls $HOME/buildscript/*.img | tail -n 1`
        id=$(gdrive upload --parent $G_FOLDER $file | grep "Uploaded" | cut -d " " -f 2)
    elif [ -z $build_orig_scr ] && [ $upload_scr ]; then
        id=$(gdrive upload --parent $G_FOLDER $file | grep "Uploaded" | cut -d " " -f 2)
    fi

    if [ $telegram_scr ] && [ $upload_scr ]; then
        bash telegram -D -M "How to get parameter of next one
        *Build for $device_scr done!*
        Download: [Drive](https://drive.google.com/uc?export=download&id=$id) "
    fi
}

build() {

    if [ -f build.log ]; then
        rm -f build.log
    fi

    if [ -f out/.lock ]; then
        rm -f out/.lock
    fi

    cd $DEVICEPATH_SCR
    mk_scr=`grep .mk AndroidProducts.mk | cut -d "/" -f "2"`
    product_scr=`grep "PRODUCT_NAME :=" $mk_scr | cut -d " " -f 3`
    cd ../../..

    printf "%s\n\n" $($cyan)
    printf "%s\n" "***********************************************"
    printf '%s\n' "Starting build with target $($yellow)"$build_type_scr""$($cyan)" for"$($yellow)" $device_scr $($cyan)"
    printf "%s\n" "***********************************************"
    printf "%s\n\n" $($reset)
    sleep 2s

    if [ "$telegram_scr" ]; then
        bash telegram -D -M "
        *Build for $device_scr started!*
        Product: *$product_scr*
        Target: *$build_type_scr*
        Started on: *$HOSTNAME*
        Time: *$(date "+%r")* "
    fi

    lunch "$product_scr"-userdebug
    make -j$(nproc) $build_type_scr |& tee build.log
}

if [ ! -z "$device_scr" ] && [ ! -z "$brand_scr" ]; then
    acquire_build_lock
if [ $prepare_source_scr ]; then
    prepare_source
fi
    function_check
    start_env
    sync_source
    setup_paths
    clean_target
    build $brand_scr $device_scr
    remove_build_lock
    upload
else
    print_help
fi
