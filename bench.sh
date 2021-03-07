#!/usr/bin/env bash

# check program if not exist
if ! [ -x "$(command -v sysbench)" ];then
    echo -e '\e[0;31m' "Error : sysbench is not installed." >&2
    echo -e '\e[0;35m' "please visit https://github.com/akopytov/sysbench
"
    exit 1
fi

if ! [ -x "$(command -v stress)" ];then
    echo -e '\e[0;31m' "Error : stress is not installed." >&2
    echo -e '\e[0;35m' "you can instal with command 'apt install stress'"
    exit 1
fi

clear # clearing terminal window

# color
red='\e[0;31m'
green='\e[1;32m'
yellow='\e[1;33m'
cyan='\e[0;36m'
purple='\e[0;35m'

# just saying hello
echo -e $cyan "Thank you so much for using benchmark scrip!!!"
echo " "

# thread count
TC=$(( $(lscpu | awk '/^Socket/{ print $2 }') * $(lscpu | awk '/^Core/{ print $4 }') * $(lscpu | awk '/^Thread/{ print $4 }') ))

# temperature
DO_TEMP(){
    unset TEMP
    # typical RPI setting
    if [ -f /sys/class/thermal/thermal_zone0/temp ]; then
        TEMP=$(cat /sys/class/thermal/thermal_zone0/temp | awk '{print $1/1000}' | cut -d "." -f1)
    fi
    # friendly arm setting
    if [ -f /sys/class/hwmon/hwmon0/device/temp_label ]; then
        TEMP=$(cat /sys/class/hwmon/hwmon0/device/temp_label | awk '{print $1/1}')
    fi
    # server
    if [ -f /sys/class/hwmon/hwmon0/temp2_input ]; then
        TEMP=$(cat /sys/class/hwmon/hwmon0/temp2_input | awk '{print $1/1000}')
    fi
}

# cpu frequancy
DO_CPU(){
    cs0=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq)
    cs1=$(($cs0/1000))
}

# showing temperature cpu
DO_IDLE(){
    DO_TEMP
    DO_CPU

    echo -e $green "CPU Idle Freq = $red$cs1$green MHz"
    echo -e $green "CPU Idle Temp = $red$TEMP$green C"
    echo " "
}

# time to start stressing the cpu to warm it up
DO_WARM(){
    DO_TEMP
    DO_CPU
    time=10
    stress_version=$(stress --version)

    echo -e $cyan "Warming up the CPU using $yellow$stress_version"
    echo -e $cyan "Timeout after $red$time$cyan seconds"
    echo -e $cyan "Spawn $red$TC$cyan workers spinning on sqrt()"
    echo " "

    stress --cpu $TC --timeout $time > /dev/null

    echo -e $green "CPU Frequancy = $red$cs1$green MHz"
    echo -e $green "CPU Temperature = $red$TEMP$green C"
    echo " "
}

# this is where the benchmarking starts
DO_PRIME(){
    DO_TEMP
    DO_CPU
    time=10
    bench=50000
    sysbench_version=$(sysbench --version)

    echo -e $cyan "Benchmark CPU using $yellow$sysbench_version"
    echo -e $cyan "Number of threads : $red$TC"
    echo -e $cyan "Upper limit for primes generator : $red$bench"
    echo -e $cyan "Limit for total execution time : $red$time$cyan second"
    echo " "

    sysbench cpu --threads=$TC --cpu-max-prime=$bench --time=$time run > bulk.txt
    
    cpu_bench=$(cat bulk.txt | grep -o "events per second:.*" | awk '{print $4}')
    total_time=$(cat bulk.txt | grep -o "total time:.*" | awk '{print $3}')
    num_even=$(cat bulk.txt | grep -o "total number of events:.*" | awk '{print $5}')
    
    echo -e $green "CPU Frequancy = $red$cs1$green MHz"
    echo -e $green "CPU Temperature = $red$TEMP$green C"
    echo -e $green "Total Time = $red$total_time"
    echo -e $green "Total Number of Events = $red$num_even$green event"
    echo -e $green "CPU Speed = $red$cpu_bench$green event/sec"
    echo " "

    rm bulk.txt
}

DO_MEM(){
    sysbench_version=$(sysbench --version)
    b_size=1K
    t_size=100G
    scope=global
    time=100

    echo -e $cyan "Benchmark Memory using $yellow$sysbench_version"
    echo -e $cyan "Size of memory block for test : $red$b_size"
    echo -e $cyan "Total size of data to transfer : $red$t_size"
    echo -e $cyan "Memory access scope : $red$scope"
    echo -e $cyan "Type of memory operations : $red$oper"
    echo -e $cyan "Limit for total execution time : $red$time$cyan second"
    echo " "

    oper=write

    sysbench memory\
     --memory-block-size=$b_size --memory-total-size=$t_size --memory-scope=$scope --memory-oper=$oper\
     --time=$time run > bulk.txt

    mem_speed=$(cat bulk.txt | grep -o "102400.00 MiB transferred.*" | awk '{print $4 $5}')
    
    echo -e $green "Memory Write Speed : $red$mem_speed"

    oper=read
    
    sysbench memory\
     --memory-block-size=$b_size --memory-total-size=$t_size --memory-scope=$scope --memory-oper=$oper\
     --time=$time run > bulk.txt
    
    mem_speed=$(cat bulk.txt | grep -o "102400.00 MiB transferred.*" | awk '{print $4 $5}')
    
    echo -e $green "Memory Read Speed : $red$mem_speed"
    echo " "

    rm bulk.txt
}

DO_IDLE
DO_WARM
DO_PRIME
DO_MEM
