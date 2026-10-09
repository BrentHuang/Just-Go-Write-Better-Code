# 第九部分 并发编程

## 概览

本部分系统介绍 Go 语言的并发编程模型，涵盖协程（Goroutine）、通道（Channel）、select 语句，以及 `time`、`context`、`sync` 等并发相关包，最后总结常用并发编程模式。Go 的 CSP 并发模型是其区别于其他语言的标志性特性。

## 章节导航

| 章节 | 核心内容 | 学习目标 |
| -- | -- | -- |
| [01 协程](01协程.md) | Goroutine 概念、启动与生命周期、调度模型、栈内存管理 | 理解 Goroutine 与线程的区别，合理使用协程 |
| [02 通道](02通道.md) | Channel 类型、有界与无界通道、单向通道、`range-close` 模式、遍历与关闭、常见陷阱 | 掌握 Channel 作为协程间通信的核心手段 |
| [03 select 语句](03select语句.md) | select 语法、多通道等待、默认分支、超时与取消 | 利用 select 实现多路复用 |
| [04 time 包](04time包.md) | 定时器、Ticker、After/AfterFunc、时间解析与格式化 | 掌握时间相关的并发控制工具 |
| [05 context 包](05context包.md) | Context 语义、取消信号传播、超时与截止时间、值传递 | 理解 Context 在请求链路中的核心作用 |
| [06 sync 包](06sync包.md) | WaitGroup、Mutex、RWMutex、Once、Cond、Map、Pool | 正确使用同步原语保护共享状态 |
| [07 并发编程模式](07并发编程模式.md) | Worker Pool、Fan-in/Fan-out、Pipeline、Goroutine 泄漏与优雅退出 | 掌握 Go 并发模式的组合与应用 |

## 学习路径与前置知识

- 学习本部分前，建议先完成第七部分（方法与接口），因为 `context.Context` 和 `sync` 相关类型大量使用接口。
- 建议按章节顺序学习：协程、通道、select 语句、time 包、context 包、sync 包并发编程模式。
- 协程和通道是 Go 并发基础，务必重点掌握；select、time 和 context 是常用工具；sync 包用于共享内存场景。
