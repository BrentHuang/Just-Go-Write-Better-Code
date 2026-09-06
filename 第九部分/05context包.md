## context 包

context 是 Go 标准库中的一个包，用于跨 Goroutine 传递截止时间、取消信号、请求域数据，是控制 Goroutine 生命周期、实现超时/取消的标准方案。文档：<https://pkg.go.dev/context>

### context.Context 接口

```go
type Context interface {
 Deadline() (deadline time.Time, ok bool)
 Done() <-chan struct{}
 Err() error
 Value(key any) any
}
```

- `Deadline() (deadline time.Time, ok bool)`：返回上下文被取消的截止时间（绝对时间），未设置截止时间则返回 ok 为 false
- `Done() <-chan struct{}`：返回一个只读通道，上下文被取消（手动取消、超时或到达截止时间等）时该通道关闭。通过 select 监听此通道是感知取消信号的标准方式
- `Err() error`：返回上下文被取消的原因。在 `Done()` 通道关闭后返回非 nil 错误（如 `context.Canceled` 或 `context.DeadlineExceeded`）；如果 `Done()` 通道尚未关闭，返回 nil
- `Value(key any) any`：根据 key 获取上下文中存储的 value，若 key 未关联任何 value 则返回 nil。应谨慎使用，通常仅用于传递请求范围（Request-Scoped）的元数据，如 RequestID、用户认证信息等

### 根上下文与派生上下文

所有上下文必须由根上下文派生，不能手动创建 Context 实例。有“主根上下文”和“占位上下文”两种根上下文：

- [func Background() Context](https://pkg.go.dev/context#Background)：返回一个空的、非 nil 的 Context 实例（主根上下文），它永远不会被取消，没有截止时间，也不存储任何 value。它通常被 main 函数、初始化和测试使用，并作为请求（Requests）的顶层上下文
- [func TODO() Context](https://pkg.go.dev/context#TODO)：返回一个空的、非 nil 的 Context 实例（占位上下文），仅当不清楚要使用哪个 Context 或 Context 尚不可用时（因为周围的函数尚未扩展以接受 Context 参数）时临时使用

四种派生上下文：

- [func WithCancel(parent Context) (ctx Context, cancel CancelFunc)](https://pkg.go.dev/context#WithCancel)：基于父 context 创建可手动取消的上下文，返回一个 cancel 函数，调用该函数可以取消返回的上下文实例。当返回的 cancel 函数被调用或父上下文的 `Done()` 通道关闭时（以先发生者为准），返回的上下文的 `Done()` 通道会关闭
- [func WithDeadline(parent Context, d time.Time) (Context, CancelFunc)](https://pkg.go.dev/context#WithDeadline)：基于父 context 创建具有截止时间（绝对时间）的上下文，到期后自动取消返回的上下文实例。如果父 context 的截止时间已经早于 d，`WithDeadline(parent, d)` 在语义上等同于父 context。当到达截止时间、返回的 cancel 函数被调用或父 context 的 `Done()` 通道关闭时（以先发生者为准），返回的上下文实例的 `Done()` 通道会关闭
- [func WithTimeout(parent Context, timeout time.Duration) (Context, CancelFunc)](https://pkg.go.dev/context#WithTimeout)：基于父 context 创建具有超时（相对时间）的上下文，超时后自动取消返回的上下文实例。等价于 `WithDeadline(parent, time.Now().Add(timeout))`
- [func WithValue(parent Context, key, val any) Context](https://pkg.go.dev/context#WithValue)：基于父 context 创建存储键值对 key-val 的上下文，可以通过返回的上下文实例的 `Value()` 方法获取存储的 value

注意：

- 链式派生，上下文不可变：每次基于父 context 调用 WithCancel、WithDeadline、WithTimeout、WithValue 返回的都是新的子上下文实例，形成上下文树，父 context 被取消时所有子上下文也会被取消
- 只要调用了 WithCancel、WithDeadline、WithTimeout，就应在函数退出前调用返回的 `cancel()` 函数（通常用 `defer cancel()`）。即使上下文因超时等原因自动取消，手动调用 `cancel()` 也能确保及时释放资源，这是一种良好的实践
- 所有派生上下文的 `Done()` 通道关闭条件相同：手动调用 cancel、超时/截止时间到达、或父上下文取消，以先发生者为准
- Context 应作为函数的第一个参数，参数名通常叫 ctx，应始终传递有效的 Context 给函数，不要传递 nil
- Context 是 Goroutine-Safe 的，同一 Context 实例可被多个 Goroutine 共享而不需要额外加锁，实现级联取消
- 调用 `cancel()` 只是发送取消信号，并非强制终止 Goroutine。Goroutine 必须监听取消信号（如检查 `ctx.Done()` 通道是否关闭），否则不会被终止
- 在 HTTP 消息处理器内部应使用请求本身携带的上下文 `r.Context()`，它能够在客户端断开连接时发出取消信号，从而及时终止下游操作
- 不要将 Context 作为结构体字段，因为 Context 传递的是请求链路的取消信号、截止时间和元数据，而非某个对象的状态

```go
// 将 Context 存储在结构体中
type Service struct {
    ctx context.Context  // 绝对不要这样做！原因：Context 的生命周期应该由调用链管理，不应作为结构体的长期状态
}

// 正确做法：将 Context 作为参数传递，并且是函数的第一个参数
func (s *Service) DoSomething(ctx context.Context) error { ... }
```

### 应用场景

#### WithCancel 上下文取消 Goroutine 的执行

通过 WithCancel 创建可取消的上下文，并将它传递给所有相关的 Goroutine。当需要取消所有操作时（例如用户中断请求），只需调用一次返回的 cancel 函数，所有监听该上下文 `Done()` 通道的 Goroutine 都会收到信号并优雅退出。

```go
func worker(ctx context.Context, id int, wg *sync.WaitGroup) { // WaitGroup 不可复制，函数传参只能使用指针
 defer wg.Done()

 for {
  select {
  case <-ctx.Done(): // 监听取消信号
   // 这里可以清理资源
   fmt.Printf("worker %d 收到取消信号，停止工作，原因: %v\n", id, ctx.Err()) // Done() 通道关闭后，Err() 返回上下文被取消的原因，如果 Done() 通道尚未关闭，Err() 返回 nil
   return                                                      // 退出循环，结束工作
  default:
   // 模拟工作
   fmt.Printf("worker %d 正在工作...\n", id)
   time.Sleep(time.Duration(rand.IntN(1000)) * time.Millisecond) // rand.IntN(n) 生成一个 [0,n) 之间的随机整数
  }
 }
}

func main() {
 // 基于主根上下文创建一个可取消的上下文
 ctx, cancel := context.WithCancel(context.Background())
 defer cancel() // 应始终调用 defer cancel()，确保上下文被取消

 // 启动多个 worker，并用 WaitGroup 等待它们全部退出
 var wg sync.WaitGroup
 workerCount := 3
 wg.Add(workerCount)
 for i := range workerCount {
  go worker(ctx, i, &wg)
 }

 // 监听 ctrl+C 等信号（在单独 Goroutine 中）
 sigs := make(chan os.Signal, 1)
 signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM) // SIGINT（Ctrl+C，或 kill -INT pid）；SIGTERM（kill pid 或 kill -TERM pid，是 kill 命令默认信号）

 wg.Go(func() {
  sig := <-sigs // 阻塞等待信号
  fmt.Printf("收到中断信号：%v，开始取消所有 worker...\n", sig)
  cancel() // 调用 cancel 函数，取消上下文
 })

 wg.Wait() // 等待所有 Goroutine 退出
 fmt.Println("所有 Goroutine 已退出，主程序退出")
}
```

#### 多个任务并发，成功一个即返回结果

```go
// 全局复用，避免每次请求都创建新的 http.Client
var httpClient = &http.Client{
 Timeout: 30 * time.Second,
}

// FetchFirstSuccessful 并发请求多个 URL，返回第一个成功 (HTTP 2xx) 的响应体。
// 若全部失败或父 ctx 取消，则返回错误。
func FetchFirstSuccessful(ctx context.Context, urls []string) ([]byte, error) {
 if len(urls) == 0 {
  return nil, errors.New("no URLs provided")
 }

 // 创建可取消的子 Context
 ctx, cancel := context.WithCancel(ctx)
 defer cancel() // 确保函数退出时取消所有子 Goroutine

 resultCh := make(chan []byte, 1) // 只取第一个成功结果，缓冲 1 防止阻塞
 done := make(chan struct{})      // 通知所有 Goroutine 已结束
 var wg sync.WaitGroup

 // 启动请求 Goroutine
 for _, url := range urls {
  wg.Add(1)
  go func(u string) {
   defer wg.Done()

   // 创建带 Context 的请求，取消 Context 会中断正在进行的请求
   req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
   if err != nil {
    slog.Error("NewRequestWithContext error", "err", err)
    return // 请求构造失败，忽略
   }

   resp, err := httpClient.Do(req)
   if err != nil {
    // context 取消是预期行为，不记错误日志
    if !errors.Is(err, context.Canceled) {
     slog.Warn("Do error", "url", u, "err", err)
    }
    return
   }
   defer resp.Body.Close()

   // 只处理 2xx 成功状态码
   if resp.StatusCode >= 200 && resp.StatusCode < 300 {
    body, err := io.ReadAll(resp.Body)
    if err != nil {
     slog.Error("ReadAll error", "err", err)
     return // 读取失败，忽略
    }
    // 非阻塞发送，若 resultCh 已有值则忽略（防止阻塞）
    select {
    case resultCh <- body:
    default: // Channel 已满   -> 跳过（丢弃结果）
    }
   }
   // 其他状态码视为失败，忽略
  }(url)
 }

 // 单独 Goroutine 等待所有请求完成，然后关闭 done 通道
 go func() {
  wg.Wait()
  close(done)
 }()

 // 等待第一个成功结果或全部结束
 select {
 case body := <-resultCh:
  cancel() // 取消其余请求（通常会立即中断）
  return body, nil
 case <-done:
  return nil, errors.New("all requests failed")
 case <-ctx.Done():
  return nil, ctx.Err() // 父 Context 取消（如超时）
 }
}

func main() {
 urls := []string{
  "https://httpbin.org/delay/3",    // 慢速响应
  "https://httpbin.org/status/200", // 立即成功
  "https://httpbin.org/status/404", // 失败
 }

 ctx := context.Background()
 // 可增加超时：ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
 // defer cancel()
 body, err := FetchFirstSuccessful(ctx, urls)
 if err != nil {
  slog.Error("FetchFirstSuccessful error", "err", err)
 } else {
  slog.Info("success", "body length", len(body))
  if len(body) > 100 {
   fmt.Println(string(body[:100]) + "...")
  } else {
   fmt.Println(string(body))
  }
 }
}
```

代码分析：

1. 三个任务并发执行，需要起三个 Goroutine，Goroutine 执行成功则将结果写入 resultCh 中。因 resultCh 只有一个缓冲位，所以只能写入一个结果，其他成功结果会被丢弃
2. Main Goroutine 中需要等待从 resultCh 读取成功结果
3. 如果三个任务均失败，resultCh 中就不会有数据可读，Main Goroutine 就永久阻塞，需要处理这种情况。Main Goroutine 不能直接 wg.Wait 三个任务 Goroutine 都结束，因为 wg.Wait 是阻塞的，所以需要另起一个 Goroutine 等待三个任务 Goroutine 都结束，并发出 done 信号通知 Main Goroutine（done 本质上是一个适配器，把 WaitGroup 的阻塞等待适配成 select 可用的 Channel 操作。这是一个常见的 Go 惯用模式）
4. 三个任务 Goroutine 和 Main Goroutine 都需要响应 cancel 信号，即监听 `ctx.Done()` 通道是否关闭。三个任务 Goroutine 中使用 NewRequestWithContext API 已经实现了取消功能，不需要额外处理

#### 多个任务并发，需完成所有任务（不管成功失败）

```go
var httpClient = &http.Client{
 Timeout: 30 * time.Second,
}

// Result 封装单个请求的返回信息
type Result struct {
 URL        string // 请求的 URL
 Body       []byte // 响应体
 StatusCode int    // HTTP 状态码（若请求失败则为 0）
 Err        error  // 请求或读取过程中的错误（nil 表示成功）
}

// FetchAll 并发请求多个 URL，等待全部完成，返回每个 URL 的结果切片
// 结果顺序与输入 urls 顺序无关（与完成顺序一致）
func FetchAll(ctx context.Context, urls []string) []Result {
 if len(urls) == 0 {
  return nil
 }

 resultCh := make(chan Result, len(urls)) // 带缓冲的 Channel，容量等于 URL 数量，防止发送阻塞

 // 启动每个 URL 的请求 Goroutine
 for _, url := range urls {
  go func(u string) {
   // 构造带 Context 的请求，以支持父级取消
   req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
   if err != nil {
    resultCh <- Result{URL: u, Err: err}
    return
   }

   resp, err := httpClient.Do(req)
   if err != nil {
    // 错误可能来自网络、超时或 Context 取消
    resultCh <- Result{URL: u, Err: err}
    return
   }
   defer resp.Body.Close()

   // 读取响应体（即使非 2xx 也读取）
   body, err := io.ReadAll(resp.Body)
   if err != nil {
    resultCh <- Result{URL: u, StatusCode: resp.StatusCode, Err: err}
    return
   }

   // 返回完整结果，状态码和 Body
   resultCh <- Result{
    URL:        u,
    Body:       body,
    StatusCode: resp.StatusCode,
    Err:        nil,
   }
  }(url)
 }

 results := make([]Result, 0, len(urls))
 for range urls {
  select {
  case res := <-resultCh:
   results = append(results, res)
  case <-ctx.Done():
   return results // ctx 取消，返回已收集的部分结果
  }
 }
 return results
}

func main() {
 urls := []string{
  "https://httpbin.org/delay/3",    // 慢速响应
  "https://httpbin.org/status/200", // 立即成功
  "https://httpbin.org/status/404", // 失败
 }

 ctx := context.Background()
 // 可增加超时：ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
 // defer cancel()

 results := FetchAll(ctx, urls)

 // 打印每个结果
 for _, res := range results {
  if res.Err != nil {
   fmt.Printf("URL: %s, Error: %v\n", res.URL, res.Err)
  } else {
   fmt.Printf("URL: %s, Status: %d, Body length: %d, Body: %s\n", res.URL, res.StatusCode, len(res.Body), string(res.Body))
  }
 }
}
```

#### WithTimeout 上下文实现超时

对于网络请求、数据库查询等可能阻塞的同步操作（也可以是异步的，这里以同步操作为例），使用 WithTimeout 或 WithDeadline 结合 Goroutine 异步调用可以实现超时机制，避免无限期等待。

```go
// 有瑕疵版本，在 Goroutine 中执行的阻塞操作不能被取消，只能自行完成，可能有副作用。真正的严格做法是让 fn 本身接受 context.Context 参数
func init() {
 slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{AddSource: true}))) // 显式文件名（完整路径）和行号
}

// 包装器，返回一个闭包，捕获了被调用的函数 fn 和超时时间 timeoutSecs
func callxxWithTimeout(fn func() error, timeoutSecs time.Duration, wg *sync.WaitGroup) func() error { // WaitGroup 不可复制，函数传参只能使用指针
 return func() error {
  ctx, cancel := context.WithTimeout(context.Background(), timeoutSecs)
  defer cancel()

  // 创建结果 Channel
  done := make(chan error, 1)

  // 在 Goroutine 中执行函数，异步调用
  wg.Go(func() {
   result := fn() // 因为 fn 是一个阻塞操作（没有 Context 参数），最终会执行完成或一直挂着。
   // 如果 fn 一直挂着不返回，这个 Goroutine 就会一直阻塞在这里，造成泄露；如果 fn 执行完成了，代码会继续往下执行。
   // 注意：如果 fn() 有副作用（如写入数据库），即使超时，副作用仍然会发生。

   // 优先检查 Context 状态
   if ctx.Err() != nil { // Done() 通道关闭后，Err() 返回上下文被取消的原因，如果 Done() 通道尚未关闭，Err() 返回 nil
    slog.Warn("已超时，丢弃结果")
    return
   }

   // 尝试发送结果（双重保护），两个 case 可能同时就绪
   select {
   case done <- result:
    slog.Info("函数正常完成")
   case <-ctx.Done():
    slog.Warn("发送结果时超时")
   }
  })

  // 在 Main Goroutine 中监听超时或完成。如果两个 case 同时就绪呢？
  select {
  case <-ctx.Done():
   // 超时或手动取消
   slog.Error("超时或手动取消", "err", ctx.Err())
   return ctx.Err()
  case err := <-done:
   // 函数正常完成
   slog.Info("函数正常完成", "result", err)
   return err
  }
 }
}

// 一个同步阻塞操作，没有 ctx 参数
func longRunningTask() error {
 time.Sleep(5 * time.Second) // 模拟 5 秒操作时间
 slog.Info("操作完成！")
 return nil
}

func main() {
 var wg sync.WaitGroup

 callxxF := callxxWithTimeout(longRunningTask, 3*time.Second, &wg) // 超时设置为 3 秒
 err := callxxF()
 if err != nil {
  slog.Error("操作失败", "err", err) // error="context deadline exceeded"，说明操作超时
 }

 wg.Wait()
}
```

设计支持取消 API 的要点：

1. 函数签名接收 `context.Context`：所有可能需要取消的 API，第一个参数应为 `ctx context.Context`
2. 在关键阻塞点检查取消信号：使用 select 监听 `ctx.Done()`，或在循环中定期检查 `ctx.Err()`

    ```go
    func doWork(ctx context.Context) error {
     for {
      select {
      case <-ctx.Done():
       return ctx.Err() // 返回取消原因
      default:
       // 执行实际工作
      }
     }
    }
    ```

3. 透传 ctx：所有中间层函数都应将 ctx 透传下去，任何环节遗漏检查则整个取消链路失效
4. 使用 `defer cancel()` 防止泄漏：

    ```go
    ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
    defer cancel() // 确保函数返回时释放资源
    ```

#### WithTimeout 实现超时重试

对于生产环境，推荐使用指数退避结合随机抖动的策略。

```go
// 当 totalTimeout=1 毫秒，而单次 operation 需要 1 秒时，ctx 会立即超时，
// http.DefaultClient.Do() 会检测到 ctx.Done()，自动取消底层的 TCP 连接，返回 context.DeadlineExceeded 错误

func init() {
 slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{AddSource: true}))) // 显式文件名（完整路径）和行号
}

func RetryWithExponentialBackoff(ctx context.Context, maxRetries int, shouldRetry func(error) bool, operation func(context.Context) error) error {
 errMaxRetry := fmt.Errorf("operation failed after %d retries", maxRetries)

 for attempt := range maxRetries {
  slog.Info("operation attempt", "attempt", attempt+1)

  // 1. 执行操作
  err := operation(ctx)
  if err == nil {
   return nil // 成功则返回
  }

  if attempt == maxRetries-1 {
   return errMaxRetry
  }

  // 2. 检查错误是否可重试
  if !shouldRetry(err) {
   return fmt.Errorf("non-retriable error: %w", err)
  }

  // 3. 计算下一次重试的等待时间（指数退避 + 抖动）
  baseDelay := time.Duration(1<<uint(attempt)) * time.Second  // 基础等待时间：2^attempt 秒
  jitter := time.Duration(rand.IntN(1000)) * time.Millisecond // 随机抖动：0-1000 毫秒
  waitTime := baseDelay + jitter

  // 4. 等待，但监听上下文取消信号
  select {
  case <-time.After(waitTime):
   // 等待时间到，继续下一次重试
  case <-ctx.Done():
   // 上下文已超时或被取消，退出重试
   return ctx.Err()
  }
 }

 return errMaxRetry // 当 maxRetries 为 0 时，会走到这里（实际中不会）
}

func main() {
 // 设置整个重试过程的超时为 30 秒
 const totalTimeout = 30 * time.Second
 ctx, cancel := context.WithTimeout(context.Background(), totalTimeout)
 defer cancel()

 // 模拟操作：发送一个 http 请求
 operation := func(ctx context.Context) error {
  // 创建请求
  req, err := http.NewRequestWithContext(ctx, http.MethodGet, "https://api.example.com", nil)
  if err != nil {
   slog.Error("NewRequestWithContext error", "err", err)
   return err
  }
  // 发送请求
  resp, err := http.DefaultClient.Do(req) // req 是带上下文的请求，超时可以自动取消
  if err != nil {
   slog.Error("Do error", "err", err)
   return err
  }
  defer resp.Body.Close() // 必须关闭 Body
  if resp.StatusCode != http.StatusOK {
   return fmt.Errorf("unexpected status code: %d", resp.StatusCode)
  }
  return nil
 }

 // 定义重试条件，例如只对网络错误或超时进行重试
 shouldRetry := func(err error) bool {
  // 这里可以根据错误的实际类型或内容进行判断
  return err != nil
 }

 const maxRetries = 5 // 最大重试次数

 err := RetryWithExponentialBackoff(ctx, maxRetries, shouldRetry, operation)

 if err != nil {
  slog.Error("final error", "err", err)
 } else {
  slog.Info("success!")
 }
}
```

#### WithValue 上下文传递请求范围数据

使用 WithValue 可以在请求的调用链（多个 API 之间）中安全地传递一些必要的元数据，如 RequestID、用户认证信息等。

使用 WithValue 时应该为 key 定义自己的类型，通常的做法是为每个包定义一个私有的、不可导出的 key 类型。不要直接使用 string 类型或其它内置类型，以避免不同包使用 Context 时发生冲突，例如都是 string 类型，不同包的同名键值可能相互覆盖。

key 必须是可比较的，因为底层用 Map 管理，key 是 any 类型，要求接口持有的具体类型可比较。

```go
package user

import "context"

type User struct{}
type Request struct{}
type Session struct{}

// 以下类型是未导出的，用于定义此包中的 Context 键类型
// 这可以防止与其它包中定义的键产生冲突
type userKeyType struct{}
type requestKeyType struct{}
type sessionKeyType struct{}

// 以下变量是 Context 中对应值的键，它们是未导出的
// 客户端应使用对应的 NewXxxContext 和 FromXxxContext 函数，而不是直接使用这些键
var userKey userKeyType
var requestKey requestKeyType
var sessionKey sessionKeyType

// UserNewContext 返回一个携带 User 值的新 Context
func UserNewContext(ctx context.Context, u *User) context.Context {
 return context.WithValue(ctx, userKey, u)
}

// UserFromContext 返回存储在 ctx 中的 User 值（如果存在）
func UserFromContext(ctx context.Context) (*User, bool) {
 u, ok := ctx.Value(userKey).(*User)
 return u, ok
}

// RequestNewContext 返回一个携带 Request 值的新 Context
func RequestNewContext(ctx context.Context, r *Request) context.Context {
 return context.WithValue(ctx, requestKey, r)
}

// RequestFromContext 返回存储在 ctx 中的 Request 值（如果存在）
func RequestFromContext(ctx context.Context) (*Request, bool) {
 r, ok := ctx.Value(requestKey).(*Request)
 return r, ok
}

// SessionNewContext 返回一个携带 Session 值的新 Context
func SessionNewContext(ctx context.Context, s *Session) context.Context {
 return context.WithValue(ctx, sessionKey, s)
}

// SessionFromContext 返回存储在 ctx 中的 Session 值（如果存在）
func SessionFromContext(ctx context.Context) (*Session, bool) {
 s, ok := ctx.Value(sessionKey).(*Session)
 return s, ok
}
```
