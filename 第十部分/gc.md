## GC

GC 会在以下三种情况下被触发：

- 内存分配量达到阈值：当新分配的堆内存达到一个阈值时触发，这是最主要的触发方式
- 定时触发：如果应用程序长时间（默认 2 分钟）没有触发 GC，后台监控线程 sysmon 会强制触发一次
- 手动触发：开发者可以在代码中调用 `runtime.GC()` 来手动触发一次 GC

[func SetGCPercent(percent int) int](https://pkg.go.dev/runtime/debug#SetGCPercent) 用于设置触发 GC 的百分比：当新分配的数据量与上一次 GC 后剩余的活跃数据量之比达到该百分比时，就会触发 GC。`SetGCPercent()` 返回之前的设置值。默认情况下，该值为系统启动时 GOGC 环境变量的值；如果未设置该环境变量，则默认为 100。为了控制内存使用量，可以适当降低该百分比。负数值则相当于禁用了垃圾回收功能，除非内存使用量已经达到上限。

```go
import (
 "fmt"
 "runtime/debug"
)

func main() {
 var stats debug.GCStats
 debug.ReadGCStats(&stats)
 fmt.Println(stats)

 percent := debug.SetGCPercent(-100)
 fmt.Println(percent)
}
```

Go 的 GC 一直在不断进化，以下是几个关键的里程碑：

- Go 1.3：这个版本将清除（Sweep）阶段改为与用户程序并发执行，减少了 STW 的时间，但标记阶段仍需 STW
- Go 1.4：实现了精确 GC（Precise GC），不再使用保守式扫描堆内存，消除了误判指针导致的“假引用”，让 GC 能准确回收所有垃圾，是后续所有 GC 优化的基础前提
- Go 1.5：引入并发的“三色标记法”，大幅降低 GC 延迟，被认为是 GC 性能的里程碑
- Go 1.8：引入“混合写屏障”，彻底消除了标记结束时的 STW，将暂停时间降至微秒级
- Go 1.14：引入异步抢占（Asynchronous Preemption），基于 OS 信号抢占协程执行。在此之前，紧密循环（无函数调用）会一直阻塞 GC 的 STW 请求，导致 GC 延迟飙高，异步抢占真正实现了微秒级的 GC 延迟
- Go 1.19：引入了 GOMEMLIMIT 环境变量，允许用户设置软内存限制，让 GC 能更好地适配容器等内存受限环境
- Go 1.26：默认启用了名为 Green Tea 的新 GC，它在 CPU 缓存局部性和多核可扩展性方面做了优化，进一步提升了性能

### 怎么分析程序的 GC 情况

todo
