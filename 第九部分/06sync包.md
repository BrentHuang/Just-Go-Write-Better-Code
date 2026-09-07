## sync 包

[sync](https://pkg.go.dev/sync) 是 Go 标准库中的一个包，提供了一些基本的同步原语，sync 包中定义的类型的值变量不可拷贝，函数传参只能使用指针。

### 并发问题的硬件根源

CPU 多级缓存结构：寄存器 -> L1/L2/L3 缓存 -> 主存（内存）

- 每个 CPU 核心有自己的 L1/L2 本地缓存，多个核心共享 L3、内存
- 写数据时优先写到本地缓存，不会立刻同步到主存
- 一个核心写入的数据，另一个核心不会立刻看到，需要缓存一致性协议（MESI）把缓存行同步过来

两种指令重排：编译器、CPU 为提升性能会打乱指令执行顺序，但保证单 Goroutine 内执行结果与代码书写顺序一致

- 编译器重排：编译优化时调整生成的机器指令顺序（反汇编能看到指令位置变了）
- CPU 重排：硬件流水线乱序执行指令，汇编代码顺序不变，但实际执行顺序不同

这些硬件根源导致两个经典问题：

内存可见性问题：Goroutine A 修改变量，Goroutine B 迟迟看不到新值（数据还在 A 的 CPU 缓存中，还没通过 MESI 协议刷到主存或同步到 B 的 CPU 缓存）

指令乱序问题：Goroutine A 写 `data=42; flag=true`，Goroutine B 可能先看到 `flag=true` 再看到 `data=42`，导致读到 data 旧值
  
```go
// Goroutine A（核心 A）:
data = 42      // 写入数据
flag = true    // 通知 B：数据已就绪

// Goroutine B（核心 B）:
if flag {
    println(data)  // 期望读到 42
}
```

解决可见性与乱序问题的底层硬件指令是内存屏障（Memory Barrier）：

- 写屏障（Store Barrier）：确保屏障前所有写操作从 Store Buffer 排空、对外可见后，才能执行屏障后操作
- 读屏障（Load Barrier）：确保屏障前所有读操作完成后，才能执行屏障后操作
  
Go 代码中不用手动写汇编屏障，同步原语（sync.Mutex、sync/atomic、Channel）内部自带内存屏障。

如果想了解 Go 内存模型，请阅读官方文档：<https://go.dev/ref/mem>

### atomic 原子变量

原子变量（Atomic Variables）是进行轻量级、无锁并发控制的核心工具，由 sync/atomic 标准库提供。

[sync/atomic](https://pkg.go.dev/sync/atomic#pkg-overview) 提供了一组以 Load、Store、Swap、CompareAndSwap、Add 为前缀的底层函数，这些函数接受指针参数，直接操作底层内存，容易出错。从 Go 1.19 开始，官方推荐使用 atomic 包中定义的类型安全的结构体，如 atomic.Int32、atomic.Uint64、atomic.Bool、atomic.Pointer[T] 等。

无论是类型安全的变量还是底层函数，都支持以下核心操作：

| 操作 | 对应方法 (以`atomic.Int32`为例) | 描述 |
| -- | -- | -- |
| 读取 (Load) | `counter.Load()` | 原子性地读取变量的当前值 |
| 写入 (Store) | `counter.Store(100)` | 原子性地将一个值写入变量 |
| 交换 (Swap) | `old := counter.Swap(200)` | 原子性地写入新值，并返回旧值 |
| 比较并交换 (CAS) | `swapped := counter.CompareAndSwap(100, 200)` | 这是实现无锁算法的核心。仅当变量当前值等于预期值（第一个参数）时，才将其更新为新值（第二个参数），并返回是否成功 |
| 增减 (Add) | `counter.Add(10)` | 原子性地对数值进行增加或减少（负值表示减少） |
| 位操作 (And/Or) | `counter.And(0xFF)`,`counter.Or(0x01)` | Go 1.23+ 支持原子性的按位与、或操作 |

```go
func main() {
 var counter atomic.Int32 // 1. 声明一个原子整数，初始值为 0
 var wg sync.WaitGroup

 for range 1000 {
  wg.Go(func() {
   counter.Add(1) // 2. 原子性地增加
  })
 }

 wg.Wait()
 // 3. 原子性地读取
 fmt.Printf("Final Counter:%d\n", counter.Load()) // 输出：1000
}
```

原子变量不可拷贝，函数传参只能使用指针。

```go
func worker(stop *atomic.Bool) { // 原子变量不可拷贝，函数传参只能使用指针
 for !stop.Load() {
  slog.Info("工作中...")
  time.Sleep(100 * time.Millisecond)
 }
 slog.Info("协程退出")
}

func main() {
 var stop atomic.Bool // 默认值为 false

 go worker(&stop)

 time.Sleep(3 * time.Second)
 stop.Store(true) // 设置退出标志

 for runtime.NumGoroutine() != 1 {
  time.Sleep(time.Second)
 }
}
```

对于任意类型的共享数据，`atomic.Value` 提供了原子性的 Load 和 Store 操作。Go 1.19+ 推荐用 `atomic.Pointer[T]` 替代 `atomic.Value` 以避免手动断言。

`atomic.Pointer[T]` 表示类型为 `*T` 的原子指针。

```go
type Config struct {
 Addr string
 Port int
}

var cfgOld atomic.Value              // 不推荐
var cfgModern atomic.Pointer[Config] // 推荐

func main() {
 old()
 modern()
}

func old() {
 cfg := &Config{Addr: "localhost", Port: 8080}

 // 写入
 cfgOld.Store(cfg)

 // 读取（必须类型断言）
 c := cfgOld.Load().(*Config)
 fmt.Printf("%T, %s:%d\n", c, c.Addr, c.Port) // *main.Config, localhost:8080
}

func modern() {
 // 写入
 cfg := &Config{Addr: "localhost", Port: 8080}
 cfgModern.Store(cfg)

 // 读取（无需类型断言）
 c := cfgModern.Load()
 fmt.Printf("%T, %s:%d\n", c, c.Addr, c.Port) // *main.Config, localhost:8080

 // CAS（比较并交换）
 old := &Config{Addr: "localhost", Port: 8080}
 new := &Config{Addr: "0.0.0.0", Port: 9090}
 swapped := cfgModern.CompareAndSwap(old, new) // false，因为比较的是指针的值（存储的地址）是否相等
 fmt.Println(swapped)

 swapped = cfgModern.CompareAndSwap(cfg, new) // true
 fmt.Println(swapped)
}
```

### sync.Map

[sync.Map](https://pkg.go.dev/sync#Map) 是标准库提供的并发安全 Map，无须额外的锁机制。适用于两种场景：

- key 只写入一次但读取多次（如只增长的缓存）
- 多个协程读写的 key 集合不相交

在这两种情况下，与使用单独的 Mutex 或 RWMutex 的普通 Map 相比，使用 sync.Map 可以显著降低锁竞争。

> [!NOTE]
> sync.Map 仅在上述特定场景下才有性能优势。一般的并发场景下，`sync.RWMutex` 包装的普通 Map 可能更简单高效。

sync.Map 的零值是一个空的 Map，可以直接使用。

```go
func main() {
 var m sync.Map // 声明 var m sync.Map 后即可直接使用，无需像普通 Map 那样必须用 Map 字面量或 make 函数初始化

 // 添加键值对或更新
 m.Store("name", "alice") // Store 方法存储或更新一个键值对
 m.Store("age", 20)
 m.Store("age", 21) // 重复 key 会覆盖旧值
 m.Store("location", "Beijing")

 // Load 方法根据 key 读取值，返回 (value, ok)，ok 表示 key 是否存在
 if v, ok := m.Load("name"); ok { // ok 为 true 表示键存在
  // 返回的 v 是一个接口类型，需要断言为具体类型
  fmt.Printf("name: %s\n", v.(string))
 }
 if v, ok := m.Load("age"); ok { // ok 为 true 表示键存在
  // 返回的 v 是一个接口类型，需要断言为具体类型
  fmt.Printf("age: %d\n", v.(int))
 }

 // 读取或写入（LoadOrStore）
 actual, loaded := m.LoadOrStore("name", "bob")
 fmt.Printf("%s %t\n", actual.(string), loaded) // alice true ("name"这个键已存在，行为为Load）

 actual, loaded = m.LoadOrStore("gender", "male")
 fmt.Printf("%s %t\n", actual.(string), loaded) // male false ("gender"这个键不存在，行为为 Store）

 // 遍历 sync.Map，给一个函数 f，s.Range(f) 会遍历 sync.Map 中的所有键值对，对每个键值对调用一次 f
 // f 的返回值为 bool，返回 true 表示继续遍历，返回 false 表示停止遍历
 // Range 方法遍历的是调用时刻的快照，遍历过程中新增或删除的键可能不会体现
 // Range 不保证遍历顺序
 m.Range(func(key, value any) bool {
  fmt.Printf("%s: %v\n", key, value)
  return true // 返回 true 继续遍历，返回 false 停止遍历
 })

 // 删除键值对
 m.Delete("age")                 // Delete 方法删除一个键值对
 if v, ok := m.Load("age"); ok { // ok 为 false 表示键不存在
  fmt.Printf("age: %d\n", v.(int))
 }
}
```

[func (m *Map) LoadOrStore(key, value any) (actual any, loaded bool)](https://pkg.go.dev/sync#Map.LoadOrStore)：如果 key 已存在则返回对应的 val，loaded 为 true；否则存储 key-value 并返回 value，loaded 为 false。

### sync.WaitGroup

[sync.WaitGroup](https://pkg.go.dev/sync#WaitGroup) 是一个计数信号量，通常用于等待一组协程执行完毕。通常，主协程会调用 WaitGroup.Go 来启动多个任务，然后调用 WaitGroup.Wait 来等待所有任务完成。

结构体定义（源代码：`${GOROOT}/src/sync/waitgroup.go`）：

```go
type WaitGroup struct {
 noCopy noCopy

 // Bits (high to low):
 //   bits[0:32]  counter
 //   bits[32]    flag: synctest bubble membership
 //   bits[33:64] wait count
 state atomic.Uint64
 sema  uint32
}
```

noCopy 是一个空结构体，实现了 sync.Locker 接口（有 Lock() 和 Unlock() 方法，虽然是空操作）：

```go
type noCopy struct{}

func (*noCopy) Lock()   {}
func (*noCopy) Unlock() {}
```

Go 的静态检查工具 go vet 有一个 -copylocks 检查器，它会扫描所有实现了 Lock/Unlock 的类型，发现它们被值拷贝（不是通过指针传递）时就会报错。

核心方法：

- [func (wg *WaitGroup) Add(delta int)](https://pkg.go.dev/sync#WaitGroup.Add)：设置等待计数，在协程启动前调用
- [func (wg *WaitGroup) Done()](https://pkg.go.dev/sync#WaitGroup.Done)：计数 -1（等价于 `Add(-1)`），一般在协程内 defer 调用
- [func (wg *WaitGroup) Wait()](https://pkg.go.dev/sync#WaitGroup.Wait)：阻塞直到计数归 0，一般在主协程调用
- [func (wg *WaitGroup) Go(f func())](https://pkg.go.dev/sync#WaitGroup.Go)：是 Go 1.25 新增的方法，在一个新协程中调用 f，并将该任务添加到 WaitGroup 中。当 f 返回时，该任务将从 WaitGroup 中移除。函数 f 不能 panic。可以简化 Add+Done 样板代码。

### sync.Mutex

[sync.Mutex](https://pkg.go.dev/sync#Mutex) 互斥锁：读读、读写互斥，适用于写多读少场景，Lock 和 Unlock 是两个常用方法。注意：

- Mutex 的零值是有效的未锁定状态
- Lock 的时候如果 Mutex 被占用了，则协程会阻塞直到 Mutex 可用
- 被锁定的 Mutex 不与特定协程关联，允许一个协程 Lock，然后在另一个协程 Unlock
- Unlock 不能在未加锁时调用，否则引发 panic
- 临界区要尽可能小，不要持有锁做 IO、网络请求等耗时操作

```go
type SafeCounter struct {
 mu sync.Mutex     // Mutex 的零值是有效的未锁定状态
 v  map[string]int // 按照惯例，在 Mutex 变量声明之后立刻声明被其保护的变量
}

// Inc 对指定 key 的计数加 1
func (c *SafeCounter) Inc(key string) {
 c.mu.Lock()
 defer c.mu.Unlock()
 // 对指定 key 的计数加 1
 c.v[key]++
}

// Value 返回指定 key 的计数器值
func (c *SafeCounter) Value(key string) int {
 c.mu.Lock()
 defer c.mu.Unlock()
 // 返回指定 key 的计数器值
 return c.v[key]
}

func main() {
 c := &SafeCounter{v: make(map[string]int)}

 // 使用 sync.WaitGroup 等待所有协程完成
 var wg sync.WaitGroup
 wg.Add(10)
 for range 10 {
  go func() {
   defer wg.Done()
   c.Inc("abc")
  }()
 }
 wg.Wait()

 fmt.Println(c.Value("abc"))
}
```

用通道模拟值为 1 的信号量（即互斥锁）：

```go

var (
 sema    = make(chan struct{}, 1) // 值为 1 的信号量
 balance int                      // 余额
)

// 存款
func Deposit(amount int) bool {
 if amount <= 0 {
  return false // 金额必须大于 0
 }

 sema <- struct{}{} // 获取令牌
 defer func() { // 用 defer 写起来确实很优雅，可以与不用 defer 对比一下
  <-sema // 释放令牌
 }()

 // 超出 int 最大值检查
 if amount > math.MaxInt-balance {
  return false
 }

 balance = balance + amount
 return true
}

// 查询余额
func Balance() int {
 sema <- struct{}{} // 获取令牌
 defer func() {
  <-sema // 释放令牌
 }()

 return balance
}

// 取款
func Withdraw(amount int) bool {
 if amount <= 0 {
  return false // 金额必须大于 0
 }

 sema <- struct{}{} // 获取令牌
 defer func() {
  <-sema // 释放令牌
 }()

 if balance < amount {
  return false // 余额不足
 }

 balance = balance - amount
 return true
}

func main() {
 Deposit(100)
 println(Balance())
 Withdraw(50)
 println(Balance())
 result := Withdraw(100)
 println(result) // false
 println(Balance())
}
```

注意：加锁的范围（即临界区）应该尽可能小，否则会失去并发优势。

### sync.RWMutex

[sync.RWMutex](https://pkg.go.dev/sync#RWMutex) 读写互斥锁：RWMutex 可以由任意数量的读者或单个写者持有，可同时加多个读锁，但读写、写写互斥，适合读多写少场景（缓存、配置）。常用方法：

- Lock：加写锁。如果 RWMutex 已被锁定用于读取或写入，则 Lock 会阻塞，直到 RWMutex 可用为止
- UnLock：释放写锁。不能在未加锁时调用，否则引发 panic
- RLock：加读锁。如果 RWMutex 已被锁定用于写入，则 RLock 会阻塞，直到 RWMutex 可用为止
- RUnlock：释放读锁。不能在未加锁时调用，否则引发 panic

RWMutex 的零值是有效的未锁定状态。

```go
var (
 mu      sync.RWMutex // RWMutex 的零值是有效的未锁定状态
 balance int          // 余额
)

// 存款
func Deposit(amount int) bool {
 if amount <= 0 {
  return false // 存款金额必须大于 0
 }

 mu.Lock()         // 获取写锁（互斥锁）
 defer mu.Unlock() // 释放写锁

 if amount > math.MaxInt-balance {
  return false
 }

 deposit(amount)
 return true
}

// 查询余额
func Balance() int {
 mu.RLock()         // 获取读锁
 defer mu.RUnlock() // 释放读锁
 return balance
}

// 取款
func Withdraw(amount int) bool {
 if amount <= 0 {
  return false // 取款金额必须大于 0
 }

 mu.Lock()         // 获取写锁（互斥锁）
 defer mu.Unlock() // 释放写锁

 if amount > balance {
  return false // 余额不足
 }

 deposit(-amount)
 return true
}

// 此函数要求已持有锁才能调用
func deposit(amount int) { balance += amount }
```

Go 官方文档明确禁止递归读锁（recursive read locking）。同一协程多次调用 `RLock()` 不保证安全，如果在两次 `RLock()` 之间有其它协程调用了 `Lock()`，则会死锁。

```go
// Mutex 不可重入：同一个协程对同一把锁加锁两次，第二次会死锁
var mu sync.Mutex

func f() {
 mu.Lock()
 defer mu.Unlock()
 fmt.Println("f 第一层锁")
 // 再次加锁：当前协程已经持有锁，死锁
 mu.Lock() // 死锁。编译器死锁报错只告诉你谁在等，不会直接告诉你谁持有了锁，你需要自己结合代码推断。
 fmt.Println("f 第二层锁")
 mu.Unlock()
}

var rw sync.RWMutex

// RWMutex 对写锁不可重入：同一个协程对同一把锁加写锁两次，第二次会死锁
func g() {
 rw.Lock()
 defer rw.Unlock()
 fmt.Println("g 第一层写锁")
 // 再次加写锁：当前协程已经持有写锁，死锁
 rw.Lock() // 死锁
 fmt.Println("g 第二层写锁")
 rw.Unlock()
}

// RWMutex 对读锁可重入：同一个协程对同一把锁加读锁两次，第二次不会死锁，但是明确不建议这样做！
func h() {
 rw.RLock()
 defer rw.RUnlock()
 fmt.Println("g 第一层读锁")
 // 再次加读锁：当前协程已经持有读锁，不会死锁
 rw.RLock() // 不会死锁
 fmt.Println("g 第二层读锁")
 rw.RUnlock()
}

func main() {
 // f()
 // g()
 h()
}
```

RWMutex 不会检查锁是谁持有的（它不记录协程 ID），所以：

- 场景 A（无写者等待）：同一个协程连续调用两次 `RLock()` 是可以通过的，读锁计数会从 1 变成 2，此时递归是成功的
- 场景 B（有写者等待）：如果在两次 `RLock()` 之间，有其它协程调用了 `Lock()` 正在排队，那么第二次 `RLock()` 就会被阻塞，导致死锁
  
死锁的原因是 Go 的 RWMutex 遵循“写者优先”（Writer Preference）原则：一旦有写锁（`Lock`）被阻塞在队列里，系统会认为“写操作更重要，不能再让新的读操作插队了，否则写者永远拿不到锁”。因此，系统会把所有后续到来的 `RLock` 请求（无论来自哪个协程）全部拦截，让写者先走。正因为第二次 `RLock` 被拦截了，而你又持有第一次的 `RLock` 没释放，所以互相等待，形成死锁。

### sync.Once

[sync.Once](https://pkg.go.dev/sync#Once) 仅执行一次：无论被多少协程调用，函数只会执行一次，典型用途：单例初始化、全局配置加载。

[func (o *Once) Do(f func())](https://pkg.go.dev/sync#Once.Do)：`sync.Once` 实例第一次调用 Do 时，会执行函数 f，后续调用 Do 方法时会直接返回（不管是不是执行同一个 f 函数）。如果 f 发生 panic，Do 会认为它已经返回。

Do 只接受无参函数。如果你的初始化逻辑需要参数，就传入一个匿名函数，让匿名函数（闭包）去调用那个带参函数。

```go
var (
 loadIconsOnce sync.Once
 icons         map[string]image.Image
)

// 并发安全
func Icon(name string) image.Image {
 loadIconsOnce.Do(loadIcons)
 return icons[name]
}

func loadIcons() {
 fmt.Println("loadIcons，无论多少个协程调用，都只执行一次")
 icons = make(map[string]image.Image)
 icons["test"] = image.NewRGBA(image.Rect(0, 0, 10, 10))
}

func main() {
 var wg sync.WaitGroup

 for range 10 {
  wg.Go(func() {
   img := Icon("test")
   fmt.Println(img)
  })
 }

 wg.Wait()
}
```

单例：

```go
type XXSingleton struct {
 data string
}

var (
 xxOnce     sync.Once
 xxInstance *XXSingleton
)

func GetXXSingleton() *XXSingleton {
 xxOnce.Do(func() { // 传入一个闭包
  fmt.Println("仅执行一次初始化")
  xxInstance = &XXSingleton{data: "sync.Once 单例"}
  // 其它的初始化逻辑
 })
 return xxInstance
}

func main() {
 var wg sync.WaitGroup
 for range 10 {
  wg.Go(func() {
   fmt.Println(GetXXSingleton().data)
  })
 }
 wg.Wait()
}
```

### sync.Pool

[sync.Pool](https://pkg.go.dev/sync#Pool) 对象池：缓存高频短期临时对象，复用内存，降低频繁创建销毁带来的 GC 压力。池内对象随时可能被 Go 运行时回收，故不能存放必须持久的数据。

核心方法：

- [func (p *Pool) Get() any](https://pkg.go.dev/sync#Pool.Get)：取出对象，有则复用，无则返回 nil 或调用 p.New 自动创建（如果 p.New 不为 nil）
- [func (p *Pool) Put(x any)](https://pkg.go.dev/sync#Pool.Put)：用完对象放回池子，不保证 Put 进去的对象一定能 Get 到，因为可能被 GC 清理掉了

Get 是“取走”语义，如果不 Put 回去，Pool 中的对象就会减少，后续 Get 会触发 New 创建新对象，失去 Pool 的复用意义。

永远不要假设 Get 拿到的对象一定存在，也永远不要指望 Get 能拿到刚刚 Put 进去的那个对象。在代码实现上，你必须写兜底逻辑：

- 如果 Get 返回 nil（且你没设置 p.New），你要自己 new 一个
- 如果 Get 返回了一个旧对象（虽然是同一个内存地址），它可能残留着上一次使用的脏数据，必须重置（Reset）后再使用

大量频繁创建同类型的字节缓冲区或复杂对象时可以使用 sync.Pool。

```go
var bufferPool = sync.Pool{
 New: func() any {
  return &bytes.Buffer{}
 },
}

func handleRequest(w http.ResponseWriter, r *http.Request) {
 buf := bufferPool.Get().(*bytes.Buffer)
 defer func() {
  buf.Reset()
  bufferPool.Put(buf)
 }()

 buf.WriteString("Hello, ")
 buf.WriteString(r.URL.Path)
 w.Write(buf.Bytes())
}
```

sync.Pool 是并发安全的，多个协程可以同时对它进行 Get 和 Put 操作，无需额外加锁。

### sync.Cond

[sync.Cond](https://pkg.go.dev/sync#Cond) 条件变量（锁 + 等待通知）：基于 Mutex/RWMutex，用于协程等待某个条件达成。

创建 sync.Cond 实例：[func NewCond(l Locker) *Cond](https://pkg.go.dev/sync#NewCond)，每个 Cond 都有一个关联的 Locker L（通常是 `*Mutex` 或 `*RWMutex`），在更改条件和调用 Cond.Wait 方法时必须持有该 Locker L。

核心方法：

- [func (c *Cond) Wait()](https://pkg.go.dev/sync#Cond.Wait)：释放锁（c.L）并阻塞等待通知，被唤醒后重新获得锁。Wait 调用前协程必须持有锁，Wait 必须包裹 for 循环判断条件，防止虚假唤醒
- [func (c *Cond) Signal()](https://pkg.go.dev/sync#Cond.Signal)：唤醒一个等待的 c 的协程。在持有锁或未持有锁的时候调用都允许
- [func (c *Cond) Broadcast()](https://pkg.go.dev/sync#Cond.Broadcast)：唤醒所有等待 c 的协程。在持有锁或未持有锁的时候调用都允许

```go
func main() {
 var wg sync.WaitGroup

 var mu sync.Mutex
 cond := sync.NewCond(&mu) // 每个 Cond 都有一个相关的锁 L（通常是 *Mutex 或 *RWMutex）
 queue := make([]int, 0, 5)
 done := false // 通知协程退出

 // 消费者
 for i := range 5 {
  wg.Go(func(id int) func() {
   return func() {
    for {
     val, shouldExit := func() (int, bool) {
      mu.Lock()
      defer mu.Unlock() // defer 在匿名函数返回时自动释放锁，覆盖所有退出路径

      // 队列为空持续等待
      for len(queue) == 0 && !done {
       cond.Wait() // Wait 内部会先释放锁，被唤醒后重新获取锁
       fmt.Printf("协程 %d 释放锁，等待被唤醒\n", id)
      }

      fmt.Printf("协程 %d 被唤醒，重新获取锁\n", id)

      if done && len(queue) == 0 {
       return 0, true // 通知退出
      }

      v := queue[0]
      queue = queue[1:]
      return v, false
     }()

     if shouldExit {
      fmt.Printf("协程 %d 退出\n", id)
      break
     }
     fmt.Printf("协程 %d 消费：%v\n", id, val)
    }
   }
  }(i))
 }

 // 生产者
 for i := range 100 {
  mu.Lock()
  queue = append(queue, i)
  cond.Signal() // 唤醒一个消费者
  mu.Unlock()
  fmt.Printf("生产者生产：%v\n", i)
 }

 // 通知所有消费者退出
 mu.Lock()
 done = true
 mu.Unlock()
 cond.Broadcast() // 唤醒所有消费者

 wg.Wait()
}
```

使用通道替代 `sync.Cond`（更 Go 风格），close 通道相当于 `cond.Broadcast()`，向通道发送一个数据相当于 `cond.Signal()`。

```go
func main() {
 var wg sync.WaitGroup
 queue := make(chan int, 5) // 通道是并发安全的

 // 消费者
 // 通道的一次消费语义（exactly-once delivery）保证了每个值只会被一个协程接收，不会重复消费
 for i := range 5 {
  wg.Go(func(id int) func() {
   return func() {
    for val := range queue { // for range 循环会在退出前接收完通道中的所有数据
     fmt.Printf("协程 %d 消费：%v\n", id, val)
    }
   }
  }(i))
 }

 // 生产者
 for i := range 100 {
  queue <- i
  fmt.Printf("生产者生产：%v\n", i)
 }
 close(queue) // 关闭通道，通知所有消费者退出

 wg.Wait()
}
```

### sync 扩展包

sync 扩展包：<https://pkg.go.dev/golang.org/x/sync>，包括下列几种并发原语

- [errgroup](https://pkg.go.dev/golang.org/x/sync/errgroup)：errgroup 为那些共同执行某项任务的子任务的协程组提供了协调、错误传播以及 Context 自动取消等功能
- [semaphore](https://pkg.go.dev/golang.org/x/sync/semaphore)：该包提供了一种加权信号量的实现
- [singleflight](https://pkg.go.dev/golang.org/x/sync/singleflight)：提供了一种用于抑制重复函数调用的机制
- [syncmap](https://pkg.go.dev/golang.org/x/sync/syncmap)：提供了一种并发映射的实现，这一实现是 sync.Map 的原型

#### errgroup

errgroup.Group 是 golang.org/x/sync/errgroup 包提供的并发原语，基于 sync.WaitGroup 封装，用于“并发执行一组子任务，任意一个出错就立即整体失败”的场景。

结构体定义如下：

```go
type Group struct {
 cancel  func()         // Context 取消函数
 wg      sync.WaitGroup // 底层 WaitGroup
 errOnce sync.Once      // 保证只记录第一个错误
 err     error          // 保存第一个出现的错误
}
```

关键方法：

- [func WithContext(ctx context.Context) (*Group, context.Context)](https://pkg.go.dev/golang.org/x/sync/errgroup#WithContext) 创建带上下文的 Group 实例，返回新创建的 group，该 group 关联一个从 ctx 派生的 Context 实例。当传递给 `g.Go()` 的函数 f 首次返回非 nil 错误，或 `g.Wait()` 首次返回时，ctx 会被取消，以先发生者为准
- [(g *Group) Go(f func() error)](https://pkg.go.dev/golang.org/x/sync/errgroup#Group.Go) 启动一个协程执行给定的函数 f，f 返回 nil：无错误，返回非 nil：group 记录第一个错误（如果多个协程返回错误，只记录第一个，后续错误被丢弃），并触发 ctx 取消（如果关联的有 ctx），该错误将由 `g.Wait()` 返回。协程必须监听 ctx 取消事件（`select <-ctx.Done()`）实现优雅退出
- [(g *Group) Wait() error](https://pkg.go.dev/golang.org/x/sync/errgroup#Group.Wait) 阻塞等待所有通过 `g.Go()` 启动的协程执行完毕，返回它们中的第一个非 nil 错误（如果有），无错误返回 nil。注意：`g.Wait()` 只会等待 `g.Go()` 启动的协程执行完毕，不会等待在 `g.Go()` 启动的协程执行的 f 函数中启动的协程
- [func (g *Group) SetLimit(n int)](https://pkg.go.dev/golang.org/x/sync/errgroup#Group.SetLimit) 将 group 中的活跃协程数量限制为最多 n 个，默认无限制，负值表示无限制，0 限制将阻止任何新的协程被添加

Group 的零值是有效的，它没有活跃协程数量限制，并且在发生错误时不自动取消（没有 cancel 能力）。基本示例：

```go
import (
 "fmt"

 "golang.org/x/sync/errgroup"
)

func main() {
 // Group 的零值，在首次出错时不自动 cancel()
 var eg errgroup.Group // 零值
 // g := errgroup.Group{} // 零值
 // g, _ := errgroup.WithContext(context.Background())

 // 在这个例子中，效果与零值一样，因为协程中没有监听 ctx 取消事件
 for i := range 5 { // 启动 5 个协程
  eg.Go(func() error {
   fmt.Printf("worker %d 开始\n", i)
   if i == 0 || i == 2 { // 可能是 worker0 或 worker2 出错，但只返回第一个错误
    fmt.Printf("worker %d 出错\n", i)
    return fmt.Errorf("worker %d failed", i)
   }
   fmt.Printf("worker %d 结束\n", i)
   return nil
  })
 }

 // 等待所有协程执行完毕，返回第一个错误
 if err := eg.Wait(); err != nil {
  fmt.Printf("第一个错误：%v\n", err)
 }
}
```

与 Context 集成，首次出错时取消所有协程：

```go

func init() {
 slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{
  AddSource: true, // 显示文件名（完整路径）和行号
 })))
}

func blockingWork(i int) error {
 // 模拟长时间阻塞的操作
 time.Sleep(time.Duration(rand.IntN(5)) * time.Second)

 if i == 2 {
  slog.Error("任务失败", "id", i)
  return fmt.Errorf("任务 %d 失败", i)
 }

 slog.Info("任务完成", "id", i)
 return nil
}

func main() {
 eg, ctx := errgroup.WithContext(context.Background())

 for i := range 5 { // 启动 5 个协程
  eg.Go(func() error {
   slog.Info("任务开始执行", "id", i)
   done := make(chan error, 1) // 注意：这里如果使用无缓冲通道，会导致被取消任务的那个工作协程执行完后往 done 中写结果时阻塞，因为没有人从 done 中读了

   // 启动工作协程
   go func() {
    done <- blockingWork(i) // 长时间阻塞的操作
   }()

   // 等待任务完成或取消（首次出错时）
   select {
   case err := <-done:
    return err
   case <-ctx.Done():
    slog.Warn("任务被取消", "id", i) // 即使任务被取消了，但工作协程无法被取消，仍会执行完成往 done 通道中写入结果
    return ctx.Err()
   }
  })
 }

 // 注意：eg.Wait 只会等待 eg.Go 启动的协程完成，不会等待在 eg.Go 中启动的协程
 if err := eg.Wait(); err != nil {
  slog.Error("错误", "err", err)
 }

 // 等待在 eg.Go 中起的工作协程执行完成
 // 注意：此轮询方式仅适用于调试/演示场景，生产环境请使用 sync.WaitGroup
 for runtime.NumGoroutine() != 1 {
  time.Sleep(time.Second)
 }
}
```

超时取消：

```go
func main() {
 ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
 defer cancel()
 eg, ctxGroup := errgroup.WithContext(ctx)

 for i := range 5 {
  eg.Go(func() error {
   timer := time.NewTimer(3 * time.Second) // 使用可取消的定时器
   defer timer.Stop()                      // 确保定时器被停止

   select {
   case <-ctxGroup.Done():
    fmt.Printf("任务 %d 被取消：%v\n", i, ctxGroup.Err()) // 所有任务都会被取消
    return ctxGroup.Err()
   case <-timer.C: // 使用 timer.C 替代 time.After，在任务被取消、函数返回的 defer 列表中会立即被清理
    fmt.Printf("任务 %d 完成\n", i)
    return nil
   }
  })
 }

 err := eg.Wait()
 fmt.Println(err) // context deadline exceeded
}
```

Group 是“一次性”的，同一个 Group 实例不应被用于不同的任务，即不能复用。原因是内部的 err 字段不会重置，errOnce 也只能用一次，复用会导致旧错误残留，行为不可预期。

```go
func main() {
 var g errgroup.Group

 // 第一轮
 g.Go(func() error {
  fmt.Println("第一轮：正常执行")
  return nil
 })
 err := g.Wait()
 fmt.Println("第一轮 Wait:", err) // nil

 // 第二轮：复用同一个 Group
 g.Go(func() error {
  fmt.Println("第二轮：再次执行")
  return fmt.Errorf("第二轮错误")
 })
 err = g.Wait()
 fmt.Println("第二轮 Wait:", err) // 第二轮错误

 // 第三轮：再试一次
 g.Go(func() error {
  fmt.Println("第三轮：再再执行")
  return nil
 })
 err = g.Wait()
 fmt.Println("第三轮 Wait:", err) // 仍旧是“第二轮错误”，而不是 nil
}
```

#### semaphore

加权信号量：总资源是一个数值预算，每个任务可以申请不同权重（n）。举例：总预算 = 10

- 小任务申请权重 1
- 大任务申请权重 4

可以同时跑：1 个大任务 (4)+6 个小任务 (6)，总和不能超过 10。

核心方法：

- [func NewWeighted(n int64) *Weighted](https://pkg.go.dev/golang.org/x/sync/semaphore#NewWeighted) 创建一个新的加权信号量，该信号量具有给定的最大并发访问权重限制
- [func (s *Weighted) Acquire(ctx context.Context, n int64) error](https://pkg.go.dev/golang.org/x/sync/semaphore#Weighted.Acquire) 获取 n 权重资源，n 非负，当资源不可用时会阻塞协程。成功返回 nil；失败返回 ctx.Err() 的结果，并且信号量状态保持不变
- [func (s *Weighted) Release(n int64)](https://pkg.go.dev/golang.org/x/sync/semaphore#Weighted.Release) 释放 n 权重资源
- [func (s *Weighted) TryAcquire(n int64) bool](https://pkg.go.dev/golang.org/x/sync/semaphore#Weighted.TryAcquire) 尝试获取资源，当资源不可用时不阻塞协程，直接返回 false

```go
func main() {
 ctx := context.Background()
 // 总权重预算 10
 sem := semaphore.NewWeighted(10)
 var wg sync.WaitGroup

 // 大任务，占用权重 4
 wg.Go(func() {
  _ = sem.Acquire(ctx, 4)
  defer sem.Release(4)
  fmt.Println("大任务运行")
 })

 // 小任务，占用权重 1
 for i := range 6 {
  wg.Add(1)
  go func(idx int) {
   defer wg.Done()
   _ = sem.Acquire(ctx, 1)
   defer sem.Release(1)
   fmt.Printf("小任务 %d 运行\n", idx)
  }(i)
 }

 wg.Wait()
}
```

#### singleflight

singleflight 的核心作用是将并发请求合并成单个请求，从而在高并发场景下防止缓存击穿（Cache Breakdown）。

缓存击穿特指热点数据过期（非缓存雪崩）的瞬间，海量请求直接穿透缓存打到数据库。singleflight 能保证在同一时刻，针对同一个 Key，只有一个请求真正去执行代价高昂的函数（如查 DB），其它请求只需等待并共享第一个请求的结果。

核心结构是 `singleflight.Group`，两个常用方法：

- [Do(key string, fn func() (interface{}, error)) (v interface{}, err error, shared bool)](https://pkg.go.dev/golang.org/x/sync/singleflight#Group.Do)：同步执行，确保对于某个特定的 key 来说，同一时间只会有一个执行过程在运行。返回的 shared 标识了这次调用是“发起者”还是“追随者”：
  - 如果 shared == false（我是发起者），可以在返回结果前，将其写入本地缓存
  - 如果 shared == true（我是追随者），则可能只使用结果，而不再重复写入缓存
- [DoChan(key string, fn func() (interface{}, error)) <-chan Result](https://pkg.go.dev/golang.org/x/sync/singleflight#Group.DoChan)：异步执行，返回一个通道接收结果

```go

import "golang.org/x/sync/singleflight"

var sf singleflight.Group

// 模拟从数据库获取数据（假设很慢）
func fetchFromDB(id string) (string, error) {
 fmt.Println("fetch from db") // 运行可以看到只会打印一次”fetch from db“
 // 模拟耗时 500ms 的 DB 查询
 time.Sleep(500 * time.Millisecond)
 return "data_for_" + id, nil
}

// 带 singleflight 保护的获取函数。没有 singleflight 时，1000 个并发请求会打爆 DB
func getDataByID(id string) (string, error) {
 // 使用 Do 方法，key 可以是业务 ID，如 user id
 v, err, shared := sf.Do(id, func() (any, error) {
  // 这里只会有一个请求真正执行，其它请求会等待并共享第一个请求的结果
  return fetchFromDB(id)
 })
 if err != nil {
  return "", err
 }

 if shared {
  // 回填 redis
 }

 return v.(string), nil
}

func main() {
 for range 10 {
  go func() {
   v, err := getDataByID("user123")
   if err != nil {
    fmt.Printf("err: %v\n", err)
    return
   }

   fmt.Printf("data: %v\n", v)
  }()
 }

 for runtime.NumGoroutine() != 1 {
  time.Sleep(time.Second)
 }
}
```

在微服务中，singleflight 通常作为“本地防护层”部署在 API Gateway 或业务服务内存中，配合 Redis 缓存使用：

- 请求到来，先查 Redis
- Redis 缓存未命中（或 key 过期），不直接查 DB，而是调用 sf.Do
- sf.Do 内部查询 DB 并根据 shared 标识是否回填 Redis
- 其它并发请求阻塞并等待该结果

这样，即便缓存瞬间失效，底层 DB 也毫无压力，完美解决了热点 key 失效带来的雪崩效应。
