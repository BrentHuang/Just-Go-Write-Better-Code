## Go 运行时 todo 这一章放哪里合适？

Go 运行时（Runtime）是静态嵌入二进制的底层支撑代码（并非 JVM 类虚拟机或 Python 解释器），程序启动自动初始化，全程接管程序与操作系统交互。源码位于 `${GOROOT}/src/runtime/`，主体由 Go 编写，Goroutine 切换、上下文调度等性能关键路径使用汇编实现；无外部运行时依赖，最简单的 `fmt.Println` 也依赖 Runtime 内存分配与调度逻辑。

Runtime 五大核心能力：

1. G-M-P 协程调度器：管理 Goroutine，实现 M:N 调度
2. 多级内存分配器：自研分配模型，直接向 OS 批量申请内存拆分复用，替代 `malloc`
3. 并发三色标记 GC：自动回收堆内存，大幅降低 STW 暂停时长
4. 系统调用与 netpoll 封装：统一适配多操作系统，通过 epoll/kqueue 实现网络 IO 多路复用（磁盘文件 IO 不经过 netpoll）
5. 栈、异常、同步管理：实现 Goroutine 动态伸缩栈与栈拷贝指针修正，`defer`/`panic`/`recover` 统一处理，实现 Channel 等并发原语底层

获取 Go 版本、系统架构等信息：

```go
func main() {
 fmt.Println(runtime.Version())       // go1.26.5
 fmt.Println(runtime.GOOS)            // linux
 fmt.Println(runtime.GOARCH)          // amd64
 fmt.Println(runtime.NumCPU())        // 12
 fmt.Println(runtime.GOMAXPROCS(0))   // 12
 fmt.Println(runtime.Compiler)        // gc
 fmt.Println(runtime.NumGoroutine())  // 1
 fmt.Println(runtime.NumCgoCall())   // 0
 fmt.Println(runtime.MemProfileRate) // 0
}
```

- `runtime.NumCPU()`：返回当前进程可用的逻辑 CPU 数量（CPU 核心数），参考 [NumCPU](https://pkg.go.dev/runtime#NumCPU)
- `runtime.GOMAXPROCS()`：设置可同时执行的 CPU 最大数量，并返回之前的设置，n < 1 时不更改当前设置，参考 [GOMAXPROCS](https://pkg.go.dev/runtime#GOMAXPROCS)

查看每个 Go 版本的变更记录：[Go Release Notes](https://tip.golang.org/doc/devel/release)
