## time 包

todo 对照一下官方文档

time 是 Go 标准库中的一个包，用于时间获取、格式化、解析、时间运算、定时器等，核心类型：`time.Time`（时间点）、`time.Duration`（时间段）。文档：<https://pkg.go.dev/time#pkg-overview>

`time.Time`：代表一个精确时间点（时刻），包含年月日时分秒、时区，类型定义：

```go
type Time struct {
 wall uint64
 ext  int64
 loc *Location
}
```

```go
func main() {
 // 获取当前本地时间
 now := time.Now()
 fmt.Printf("当前时间：%v\n", now) // 当前时间：2026-08-18 08:04:28.437272378 +0800 CST m=+0.000017957
 // 获取 UTC 时间
 utcNow := time.Now().UTC()
 fmt.Printf("UTC 时间：%v\n", utcNow) // UTC 时间：2026-08-18 00:04:28.437385163 +0000 UTC
}
```

`time.Duration`：代表一个时间段，单位纳秒，类型定义：`type Duration int64`。内置常量：

- time.Nanosecond  // 1 纳秒，$10^{-9}$ 秒
- time.Microsecond // 1 微秒，$10^{-6}$ 秒
- time.Millisecond // 1 毫秒，$10^{-3}$ 秒
- time.Second      // 1 秒
- time.Minute      // 1 分钟
- time.Hour        // 1 小时

```go
func main() {
 var d time.Duration = 2*time.Hour + 30*time.Minute
 fmt.Println(d) // 2h30m0s

 fmt.Println(d.Hours())        // 2.5，换算成小时
 fmt.Println(d.Minutes())      // 150，换算成分钟
 fmt.Println(d.Seconds())      // 9000，换算成秒
 fmt.Println(d.Milliseconds()) // 9000000，换算成毫秒
 fmt.Println(d.Microseconds()) // 9000000000，换算成微秒
 fmt.Println(d.Nanoseconds())  // 9000000000000，换算成纳秒
}
```

与外部系统（文件配置项、数据库、网络传输）对接时尽量使用 `time.Time` 和 `time.Duration`。当不能使用 `time.Time` 时，请使用 `string` 和 RFC 3339 中定义的格式时间戳；当不能使用 `time.Duration` 时，请使用 `int` 或 `float64`，并在字段名称中包含单位，例如字段名为 IntervalMillis，而不是 Interval。

### 时间分量

获取时间分量：从 `time.Time` 提取年、月、日、时、分、秒、星期

```go
func main() {
 now := time.Now()
 year, mon, day := now.Date()
 hour, min, sec := now.Clock()
 week := now.Weekday() // 0=周日，1=周一...6=周六

 fmt.Printf("年:%d 月:%d 日:%d\n", year, mon, day)
 fmt.Printf("时:%d 分:%d 秒:%d\n", hour, min, sec)
 fmt.Printf("星期:%d\n", week)
}
```

根据时间分量创建 `time.Time`：[func Date(year int, month Month, day, hour, min, sec, nsec int, loc *Location) Time](https://pkg.go.dev/time#Date)

### 时间字符串格式化

Go 不使用 `YY-MM-DD HH:MM:SS` 形式的格式化模板，而是使用如下形式的模板：

| 用途 | 模板字符串 |
| -- | -- |
| 年月日时分秒 | `2006-01-02 15:04:05` |
| 年月日 | `2006-01-02` |
| 时分秒 | `15:04:05` |
| 带毫秒 | `2006-01-02 15:04:05.000` |

还有预定义模板，如 `time.RFC3339`。

`time.Time` 转字符串：[func (t Time) Format(layout string) string](https://pkg.go.dev/time#Time.Format)

```go
func main() {
 now := time.Now()
 str := now.Format("2006-01-02 15:04:05") // 使用 Go 的时间格式化模板
 fmt.Printf("格式化时间：%s\n", str)
}
```

字符串解析成 `time.Time`：[func Parse(layout, value string) (Time, error)](https://pkg.go.dev/time#Parse)，注意：Parse 默认解析为 UTC，本地时区解析需要用 [func ParseInLocation(layout, value string, loc *Location) (Time, error)](https://pkg.go.dev/time#ParseInLocation)

```go
func main() {
 strTime := "2026-06-16 12:30:00"
 t, err := time.Parse("2006-01-02 15:04:05", strTime)
 if err != nil {
  panic(err)
 }
 fmt.Printf("解析后的时间：%v\n", t) // 解析后的时间：2026-06-16 12:30:00 +0000 UTC
}
```

### 时间运算与比较

时间加减得到新的 `time.Time`：[func (t Time) Add(d Duration) Time](https://pkg.go.dev/time#Time.Add)，不要使用加号

```go
func main() {
 now := time.Now()
 // +1 小时
 t1 := now.Add(1 * time.Hour) // 不要使用加法 +
 // -30 分钟
 t2 := now.Add(-30 * time.Minute)
 // 加 1 年
 t3 := now.AddDate(1, 0, 0) // 参数：年、月、日

 fmt.Printf("一小时后：%s\n", t1.Format("2006-01-02 15:04:05"))
 fmt.Printf("30 分钟前：%s\n", t2.Format("2006-01-02 15:04:05"))
 fmt.Printf("1 年后：%s\n", t3.Format("2006-01-02 15:04:05"))
}
```

两个时间相减得到 `time.Duration`：[func (t Time) Sub(u Time) Duration](https://pkg.go.dev/time#Time.Sub)，不要使用减号

```go
func main() {
 t1 := time.Now()
 t2 := t1.Add(10 * time.Second) // 不要使用加法 +
 diff := t2.Sub(t1) // 不要使用减法 -
 fmt.Printf("相差秒数：%d\n", diff.Seconds())

 start := time.Date(2000, 1, 1, 0, 0, 0, 0, time.UTC) // 根据时间分量创建 time.Time
 end := time.Date(2000, 1, 1, 12, 0, 0, 0, time.UTC)

 difference := end.Sub(start) // 计算两个时间点之间的间隔，单位纳秒
 fmt.Printf("difference = %v\n", difference)
}
```

[func Since(t Time) Duration](https://pkg.go.dev/time#Since) 测量耗时，返回 `time.Duration`，等价于 `time.Now().Sub(t)`

```go
func main() {
 start := time.Now()
 // ... 执行一些操作
 elapsed := time.Since(start)
 fmt.Printf("耗时：%v\n", elapsed)
}
```

时间比较：[func (t Time) Before(u Time) bool](https://pkg.go.dev/time#Time.Before)，[func (t Time) After(u Time) bool](https://pkg.go.dev/time#Time.After)，[func (t Time) Equal(u Time) bool](https://pkg.go.dev/time#Time.Equal)，不要使用 `>=`、`<=`、`==`

```go
func main() {
 t1 := time.Now()
 t2 := t1.Add(1 * time.Hour)

 fmt.Println(t2.After(t1))  // true t2 在 t1 之后，不要用 t2 >= t1 进行比较
 fmt.Println(t1.Before(t2)) // true t1 在 t2 之前，不要用 t1 <= t2 进行比较
 fmt.Println(t1.Equal(t2))  // false 是否相等，不要用 t1 == t2 进行比较
}
```

### 时间戳转换

[func (t Time) Unix() int64](https://pkg.go.dev/time#Time.Unix) 将 `time.Time` 转换为 Unix 时间戳（自 1970 年 1 月 1 日 UTC 以来经过的秒数）：

```go
func main() {
 now := time.Now()
 sec := now.Unix()     // 秒级时间戳，int64 类型
 ms := now.UnixMilli() // 毫秒级
 us := now.UnixMicro() // 微秒级
 ns := now.UnixNano()  // 纳秒级
 fmt.Printf("秒戳：%d\n", sec)
 fmt.Printf("毫秒戳：%d\n", ms)
 fmt.Printf("微秒戳：%d\n", us)
 fmt.Printf("纳秒戳：%d\n", ns)
}
```

[func Unix(sec int64, nsec int64) Time](https://pkg.go.dev/time#Unix) 将 Unix 时间戳转换为本地时间 `time.Time`，参数：秒，纳秒偏移

```go
func main() {
 secs := int64(1771000000)
 t := time.Unix(secs, 0) // 参数：秒，纳秒偏移
 fmt.Printf("时间戳转时间：%s\n", t.Format("2006-01-02 15:04:05"))
}
```

### 时区操作

本地时区 / UTC：

```go
func main() {
 t1 := time.Now() // 本地时区
 t2 := t1.UTC()   // UTC 零时区
 fmt.Printf("本地时区：%s\n", t1.Format("2006-01-02 15:04:05"))
 fmt.Printf("UTC 零时区：%s\n", t2.Format("2006-01-02 15:04:05"))
}
```

[func LoadLocation(name string) (*Location, error)](https://pkg.go.dev/time#LoadLocation) 加载指定时区（需时区数据库）：

```go
func main() {
 // 加载上海时区
 loc, err := time.LoadLocation("Asia/Shanghai")
 if err != nil {
  panic(err)
 }
 // 按时区解析字符串
 t, _ := time.ParseInLocation("2006-01-02", "2026-06-16", loc)
 fmt.Println(t)
}
```

### 定时器与延时

#### time.Sleep 阻塞

[func Sleep(d Duration)](https://pkg.go.dev/time#Sleep) 阻塞：

```go
func main() {
 fmt.Println("开始等待...")
 time.Sleep(2 * time.Second)
 fmt.Println("等待 2 秒结束")
}
```

#### 周期性定时器

[time.Ticker](https://pkg.go.dev/time#Ticker) 周期性定时器，用 [func NewTicker(d Duration) *Ticker](https://pkg.go.dev/time#NewTicker) 创建：

```go
func main() {
 ticker := time.NewTicker(1 * time.Second)
 defer ticker.Stop() // 记得关闭，防止泄露

 for range ticker.C {
  fmt.Println("每秒执行一次")
 }
}
```

[func Tick(d Duration) <-chan Time](https://pkg.go.dev/time#Tick) 是 NewTicker 的便捷封装，底层会创建一个 time.Ticker 对象。从 Go 1.23 开始，GC 能自动回收未引用的 Ticker 对象（无需调用 Stop），因此优先使用 Tick 而非 NewTicker。

```go
func main() {
 c := time.Tick(1 * time.Second) // 优先使用 Tick 创建周期性定时器

 for range c {
  fmt.Println("每秒执行一次")
 }
}
```

#### 一次性定时器

[time.Timer](https://pkg.go.dev/time#Timer) 一次性定时器，支持手动停止、重置。用 [func NewTimer(d Duration) *Timer](https://pkg.go.dev/time#NewTimer) 创建。

- [func (t *Timer) Stop() bool](https://pkg.go.dev/time#Timer.Stop) 阻止 Timer 触发（即不再向其 Channel C 发送当前时间，也不再执行 AfterFunc 注册的函数）。返回 true：Stop 成功，Stop 前 Timer 处于活动状态且尚未触发；返回 false：Timer 已触发或已停止。Stop 返回 false 时不能假设 Timer 的接收操作（`<-timer.C`）或 AfterFunc 注册的函数已经完成
- [func (t *Timer) Reset(d Duration) bool](https://pkg.go.dev/time#Timer.Reset) 重置过期时间为 d 后重新计时。返回 true:重置前 Timer 处于活动状态且尚未触发；返回 false：重置前 Timer 已触发或已停止。

为避免旧事件残留，建议总是先调用 Stop 再调用 Reset：

```go
if !timer.Stop() {
    // 如果 Stop 返回 false，说明定时器已经触发
    // 需要“排空”可能已经发生的事件，例如从 Channel 中尝试接收一次
    <-timer.C      // 对于 Timer.C 场景
    // 对于 AfterFunc，需要使用额外的同步机制（如 done Channel），或者让回调函数具备幂等性，或者使用原子标志避免重复执行带来的副作用
}
timer.Reset(d)
```

高频循环超时场景，反复创建销毁 timer 会造成 GC 压力，用 NewTimer + Reset 复用对象，性能更好。

```go
func main() {
 timer := time.NewTimer(1 * time.Second)
 defer timer.Stop()

 slog.Info("开始")
 for i := range 5 {
  // 重置前先停止并排空
  if !timer.Stop() {
   select {
   case <-timer.C:
   default:
   }
  }

  // 重置等待时长
  timer.Reset(time.Duration(i+1) * time.Second)
  <-timer.C
  slog.Info("超时", "times", i+1)
 }
}
```

[func After(d Duration) <-chan Time](https://pkg.go.dev/time#After) 一次性超时定时器，等待指定时间后，将当前时间发送到返回的通道。无法手动停止，底层会创建一个 `time.Timer`。

```go
func main() {
 c := make(chan int)

 for {
  // 每次循环都需要独立的超时控制，期望每次接收数据最多等待 3 秒
  select {
  case data := <-c:
   fmt.Printf("收到数据：%d\n", data)
  case <-time.After(3 * time.Second): // 每次迭代都重新计时
   fmt.Println("本次循环超时")
  }
 }
}
```

上述代码有一个陷阱：time.After 创建的定时器无法立即取消。每次循环都会创建一个新的超时定时器，假设 c 通道很快就有数据可读，那么 3 秒内可能循环了成千上万次，也就创建了成千上万个超时定时器，这些定时器还会继续运行 3 秒才会被 GC 回收（从 Go 1.23 开始，垃圾回收器能够自动回收那些未被引用且未被停止的计时器）。

优化方案：复用定时器或使用 context.WithTimeout：

```go
// 复用定时器，使用 time.NewTimer 替代 time.After
func main() {
 c := make(chan int)

 timer := time.NewTimer(3 * time.Second)
 defer timer.Stop()

 for {
  timer.Reset(3 * time.Second) // 每次循环复用同一个定时器

  select {
  case data := <-c:
   fmt.Printf("收到数据：%d\n", data)
  case <-timer.C:
   fmt.Println("本次循环超时")
  }
 }
}
```

```go
// 使用 context.WithTimeout
func main() {
 c := make(chan int)

 for {
  ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)

  select {
  case data := <-c:
   fmt.Printf("收到数据：%d\n", data)
   cancel() // 取消上下文，释放资源
  case <-ctx.Done():
   // 此时 context 已自动清理
   fmt.Println("本次循环超时")
  }
 }
}
```

[func AfterFunc(d Duration, f func()) *Timer](https://pkg.go.dev/time#AfterFunc) 用于在指定的时间间隔之后启动一个新的 Goroutine 来执行用户提供的函数 f，调用 AfterFunc 后立即返回，不会等待函数 f 执行才返回。返回的 `*Timer` 定时器可以被终止（Stop）或重置（Reset）。

```go
func init() {
 slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
  AddSource: true,
 }))) // 显式文件名（完整路径）和行号
}

func main() {
 slog.Info("Goroutine 信息", "count", runtime.NumGoroutine())

 // 2 秒后打印消息
 timer := time.AfterFunc(2*time.Second, func() {
  slog.Info("Goroutine 信息", "count", runtime.NumGoroutine()) // 2
  slog.Info("2 seconds have passed")
 })

 // 检查是否还能取消
 time.Sleep(1 * time.Second)

 slog.Info("Goroutine 信息", "count", runtime.NumGoroutine())

 if timer.Stop() {
  fmt.Println("Timer stopped before it fired")
 } else {
  fmt.Println("Timer already fired or stopped")
 }

 slog.Info("Goroutine 信息", "count", runtime.NumGoroutine())

 // 重置
 timer.Reset(2 * time.Second)
 slog.Info("Goroutine 信息", "count", runtime.NumGoroutine())
 fmt.Println("Waiting for timer to fire...")
 time.Sleep(3 * time.Second)
 slog.Info("Goroutine 信息", "count", runtime.NumGoroutine())
}
```
