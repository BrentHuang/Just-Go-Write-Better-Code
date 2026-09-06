## select 语句

select 是 Go 中用于处理多个通道操作的控制结构，类似于 switch，但专门用于通道的读写。基本语法：

```go
select {
case <-c1:
    // c1 可读时执行
case data := <-c2:
    // c2 可读时执行
case c3 <- value:
    // c3 可写时执行
default:
    // 所有 case 都不满足时执行（非阻塞）
}
```

select 语句允许 Goroutine 同时等待多个通道操作，它会阻塞直到某个 case 就绪。多个 case 同时就绪时随机选择一个执行，然后在下一次外层循环（如果有）执行仍然就绪的 case。

```go
func main() {
 ca := make(chan string, 1) // 使用缓冲通道确保发送不阻塞
 cb := make(chan string, 1)

 // 模拟几乎同时就绪的多个 case
 ca <- "消息来自 A"
 cb <- "消息来自 B"

 // Loop:
 for {
  select {
  case msg := <-ca:
   fmt.Printf("处理 A: %s\n", msg)
   // 处理完 A 后，可以在这里添加 return 来退出循环
   // 注意：使用不带标签的 break 不能退出 for 循环，仅提前结束当前 case 分支；使用 break <label> 可以退出 for 循环
  case msg := <-cb:
   fmt.Printf("处理 B: %s\n", msg)
   // 处理完 B 后，可以在这里添加 return 来退出循环
  default:
   fmt.Println("没有就绪的通道，执行其它任务或退出...")
   return // 退出 for 循环
  }
 }
}
```

反复执行几次以上代码，会发现每次随机选择就绪的一个 case 执行。

与 switch-case 中的 break 类似，不带标签的 break 会提前结束当前 case 分支，在 case 分支的结尾加不加 break 都一样。

### 永久阻塞与非阻塞

所有 case 都不满足，或压根就没有 case 分支时，

- 如果没有 default 分支，则 select 将永久阻塞
- 如果有 default 分支，则立即执行 default，此时 select 就是非阻塞的了

```go
func f() {
 for {
  select {
  default: // 压根就没有 case 分支，则立即执行 default 分支。这里的效果与去掉 select 语句是一样的
   fmt.Println("hello")
  }
 }
}

func main() {
 go f()

 select {} // 没有 case 分支，也没有 default 分支，Main Goroutine 会一直阻塞，这样 main() 函数就不会退出
}
```

空的 select 语句 `select {}`：没有 case 分支，也没有 default 分支，将永久阻塞当前 Goroutine，常用于阻止 Main Goroutine 退出。与 `for {}` 导致 CPU 忙等待不同，`select {}` 会被 Go 调度器挂起，几乎不占用 CPU 资源。

按下 Ctrl+C 时，操作系统发送 SIGINT 信号终止进程，内部所有 Goroutine（包括 `select {}` 阻塞的 Goroutine）也随之结束。

给阻塞操作设置超时：

```go
func main() {
 start := time.Now()
 // 创建一个定时器（定时触发），每 100 毫秒发送当前时间值（time.Time 类型）到返回的通道
 tick := time.Tick(100 * time.Millisecond)
 // 创建一个超时定时器（只触发一次），在 500 毫秒后发送当前时间值（time.Time 类型）到返回的通道
 boom := time.After(500 * time.Millisecond) // 在循环外创建一次，整个循环共享同一个超时
 // time.Duration 表示两个时间点之间的时间间隔，单位为纳秒
 elapsed := func() time.Duration { return time.Since(start).Round(time.Millisecond) }

 // 整个循环有一个总时间限制，不管处理多少条数据，N 秒后必须退出
 for { // 循环等待 tick 或 boom 通道有值，从 boom 通道接收值后退出循环
  select {
  case <-tick:
   fmt.Printf("[%6s] tick. \n", elapsed())
  case <-boom:
   fmt.Printf("[%6s] boom. \n", elapsed())
   return
  default:
   fmt.Printf("[%6s]    . \n", elapsed())
   time.Sleep(50 * time.Millisecond)
  }
 }
}
```

### for 循环+select 持续监听

实际应用中，通常在 select 外面套一层 for 循环持续监听多个通道事件。同时，通过监听一个特定的退出通道（一般名为 done 或 quit），可以实现 Goroutine 的优雅退出。

```go
// 在这个示例中，“结束”由接收者控制，接收者接收完数据后，向 quit 通道发送一个数据，通知发送者退出
func fibonacci(c chan<- int, quit <-chan struct{}) {
 x, y := 0, 1

 for {
  select {
  case c <- x:
   fmt.Printf("send: %d\n", x)
   x, y = y, x+y
  case <-quit: // 读取，但不关心值（丢弃）
   fmt.Println("sender quit")
   return // 或 break <label>, 退出循环并结束函数
  }
 }
}

func main() {
 c := make(chan int)
 quit := make(chan struct{}) // 使用空结构体（size 为 0）作为退出信号

 // 接收者
 go func() {
  for range 10 {
   fmt.Printf("recv: %d\n", <-c)
  }
  quit <- struct{}{} // 接收完 10 个数据后，向 quit 通道发送一个数据，通知发送者退出
  fmt.Println("receiver done")
 }()

 // 发送者
 fibonacci(c, quit)

 for runtime.NumGoroutine() != 1 {
  time.Sleep(time.Second)
 }

 fmt.Println("main done")
}
```

### 临时屏蔽 case 分支

向 nil 通道发送或从 nil 通道接收会永久阻塞。在循环中根据条件将某个通道置为 nil，从而临时屏蔽该分支。

```go
func main() {
 originTask := make(chan int)
 task := originTask // 任务通道（初始启用状态）
 pause := make(chan bool)
 pauseAck := make(chan struct{})
 done := make(chan struct{})

 // 工作 Goroutine
 go func() {
  for {
   select {
   case <-done:
    fmt.Println("工作结束")
    return
   case paused := <-pause:
    // 根据收到的值决定是否暂停任务通道
    if paused {
     task = nil // 暂停任务通道
     fmt.Println("任务通道已暂停")
    } else {
     task = originTask // 恢复任务通道
     fmt.Println("任务通道已恢复")
    }
    pauseAck <- struct{}{} // 确认状态切换完成
   case num := <-task: // 只有当 task != nil 时才可能被选中
    fmt.Printf("处理任务：%d\n", num)
    time.Sleep(200 * time.Millisecond)
   }
  }
 }()

 // 控制流程
 pause <- false
 <-pauseAck // 等待 worker 确认恢复
 task <- 1
 task <- 2

 pause <- true
 <-pauseAck // 等待 worker 确认暂停

 pause <- false
 <-pauseAck // 等待 worker 确认恢复
 task <- 3  // 假设没有 pauseAck，如果工作 Goroutine 还没有处理完上一句，task 通道就还是 nil，这里就会永久阻塞造成死锁

 close(done) // 通知工作 Goroutine 退出

 for runtime.NumGoroutine() != 1 {
  time.Sleep(time.Second)
 }
}
```

### 示例：二叉树的遍历和检查

```go
import (
 "testing"

 "golang.org/x/tour/tree"
)

// Walk 遍历树 t，并将树中所有的值发送到通道 c
func Walk(t *tree.Tree, c chan<- int) {
 // 递归遍历左子树
 if t.Left != nil {
  Walk(t.Left, c)
 }

 // 当前节点
 c <- t.Value

 // 递归遍历右子树
 if t.Right != nil {
  Walk(t.Right, c)
 }
}

// Same 判断 t1 和 t2 是否包含相同的值
// 注意：此实现假设两棵树都恰好有 10 个节点（tour 中 tree.New 的固定行为）
func Same(t1, t2 *tree.Tree) bool {
 c1 := make(chan int)
 c2 := make(chan int)
 go Walk(t1, c1)
 go Walk(t2, c2)
 for range 10 {
  if <-c1 != <-c2 {
   return false
  }
 }
 return true
}

func TestWalkTree(t *testing.T) {
 c := make(chan int)
 go Walk(tree.New(1), c)
 for i := range 10 {
  got := <-c
  if got != i+1 {
   t.Errorf("Walk(tree.New(1), ch) is not same, expect %d, got %d", i+1, got)
  }
 }
}

func TestSameTree(t *testing.T) {
 if !Same(tree.New(1), tree.New(1)) {
  t.Error("tree.New(1) is not same")
 }
}

func TestNotSameTree(t *testing.T) {
 if Same(tree.New(1), tree.New(2)) {
  t.Error("tree.New(1) and tree.New(2) are same")
 }
}
```
