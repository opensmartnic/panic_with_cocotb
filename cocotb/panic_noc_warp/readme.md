panic_noc_warp负责switch部分的功能，是对其他开源的switch（https://github.com/anan-cn/Open-Source-Network-on-Chip-Router-RTL ）的封装。

1. panic_noc_warp使用tdest信号线来标识数据报文要被发送到哪个端口
2. 初步观察到的发送至接收的延迟是7~10时钟，尚不清楚具体的数值，也不清楚cocotb端的发送代码是否会影响这个数值
3. tdest指示的目的端口不能和源端口一样，即不能自己发送给自己。尚不清楚是哪部分的原因，实际仿真时，如果自己发送给自动将导致随机性的报文丢失。
4. 在发送报文时，panic descriptor会被解析，尤其是其中的大小字段,设置不当，比如偏小，会使得报文内容被截断

各端口分布图：

![Image](port_map.png)

