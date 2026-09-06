## defer 延迟

defer 用于延迟执行函数调用，通常用于资源清理、锁释放、错误处理等场景。基本语法：

```go
defer 函数名(参数1，参数2)
```

defer 的核心语义是“延迟执行”，即在当前函数的执行流程结束前，按逆序（LIFO，后进先出）执行当前函数中所有被 defer 的函数体。特别注意：被 defer 的函数调用，其参数会立即求值固定下来（而不是在延迟执行函数体时才计算参数），但函数体的执行会推迟到返回值求值之后、当前函数返回之前执行。

```go
func main() {
 a := 1

 defer fmt.Println(a + 1) // 被 defer 的函数调用，其参数会立即求值固定下来，这里的参数是 2。最后输出 2
 defer fmt.Println(a + 2) // 被 defer 的函数调用，会被压入一个栈中（后进先出）。倒数第二输出 3

 a++            // 前面两个被 defer 的函数调用，其参数已经固定下来了，不受这里 a++ 的影响
 fmt.Println(a) // 首先输出 2
 a++
}

// 输出：2 3 2
```

被 defer 的函数体在当前函数的执行流程结束前被调用，包括两种情形：

- 正常流程：进入当前函数 -> 执行代码 -> 遇到 return -> 计算返回值，如果当前函数使用命名返回值就赋值给命名返回值变量，非命名返回值就将值存入临时位置（赋值给临时变量） -> 按 LIFO 执行当前函数的 defer 列表 -> 当前函数返回（命名返回值或临时变量）
- 发生 panic 时流程：进入当前函数 -> 执行代码 -> 发生 panic -> 中断当前函数的执行 -> 按 LIFO 执行当前函数的 defer 列表 -> 如果某个被 defer 的函数体中有 `recover()`，当前函数执行完 defer 列表后直接返回（不会继续执行 panic 发生点之后的代码），调用当前函数的上层函数从调用点之后继续执行；否则，当前函数执行完 defer 列表后，继续将 panic 传播给它的调用者 -> 如果传播到 `main()` 仍没有 `recover()` 则程序崩溃

### defer 闭包对函数返回值的影响

defer 语句本身不是闭包。当 defer 后跟匿名函数且捕获了外部变量时，才形成闭包。

如果当前函数使用命名返回值，defer 闭包捕获了命名返回值变量，可以直接修改它们，会影响最终的返回值。

因为被 defer 的函数体的执行时机在返回值求值之后、当前函数返回之前。如果当前函数使用非命名返回值：

- 返回值类型是值类型：defer 闭包无法修改返回值，因为待返回的临时变量的赋值发生在 defer 闭包执行之前，待返回的临时变量是局部变量的一个副本，defer 闭包修改的是局部变量本身，不影响最终返回的临时变量
- 返回值类型是指针：defer 闭包可以修改返回值，因为待返回的临时指针变量存储的就是局部变量的地址，defer 闭包修改这些局部变量会影响最终的返回值
- 返回值类型是切片、map 引用类型：defer 闭包可以修改返回值，因为待返回的临时“引用头”变量与局部变量共享同一份底层数据，defer 闭包修改这些局部变量的元素（底层数据）会影响到最终的返回值

应避免在 defer 闭包中修改当前函数的返回值，被 defer 的代码仅应进行日志记录、资源清理等无副作用的操作。

```go
// 命名返回值，可以在 defer 闭包中修改
func add(x, y int) (sum int) {
 defer func() {
  sum += 10  // 修改命名返回值
 }()
 return x + y  // 执行顺序：1. 当前函数的 return 语句计算返回值并赋值给命名返回值 sum 2. 执行被 defer 的函数体修改 sum 3. 当前函数 return 返回 sum
}

func main() {
 fmt.Println(add(2, 3))  // 输出 15
}
```

```go
// 指针类型的返回值，可以在 defer 闭包中修改
func returnsPointer() *int {
 val := 10
 defer func() {
  val++  // 修改指针 &val 所指向的内存地址中的值
 }()
 // 返回局部变量 val 的地址（在 Go 中合法，val 会逃逸到堆内存）
 return &val  // 执行顺序：1. 非命名返回值，将计算好的返回值，即 val 的地址存入临时位置（赋值给临时指针变量）2. 执行被 defer 的函数体修改 val 的值 3. 当前函数 return 返回临时指针变量，即 val 的地址，其指向的值已经在 defer 中被修改了
}

func main() {
 p := returnsPointer()
 fmt.Printf("通过指针间接修改返回值：%d\n", *p)  // 输出：11
}
```

```go
// 切片、map 等引用类型的返回值，可以在 defer 闭包中修改
func returnsSlice() []int {
 s := []int{10}
 defer func() {
  s[0]++ // 修改切片底层数组元素
 }()
 return s // 执行顺序：1. 非命名返回值，将计算好的返回值，即 s 的“引用头”存入临时位置（赋值给临时变量）2. 执行被 defer 的函数体修改 s 的底层数组元素 3. 当前函数 return 返回临时“引用头”变量（与 s 共享同一份底层数据）
}

func main() {
 s := returnsSlice()
 fmt.Printf("通过切片间接修改返回值：%v\n", s) // 输出：[11]
}
```

```go
// 非命名返回值，且不是指针、引用类型，无法在 defer 闭包中修改
func anonymousReturn() int {
 var result int
 defer func() {
  result++                                       // 修改的是局部变量 result，而非函数最终的返回值
  fmt.Printf("在 defer 中，局部变量 result = %d\n", result) // 11
 }()
 result = 10
 fmt.Printf("在 return 前，result = %d\n", result) // 10
 return result                              // 执行顺序：1. 非命名返回值，将计算好的返回值，即 result 的值存入临时位置（赋值给临时变量），待返回的临时变量是 result 的一个副本，此后修改 result 不影响这个副本 2. 执行被 defer 的函数体修改 result 3. 当前函数 return 返回临时变量
}

func main() {
 fmt.Printf("匿名返回值函数结果：%d\n", anonymousReturn()) // 输出：10
}
```

Go 中 return 语句并非原子操作，它大致分为三步：

- 设置需要返回的值：对于命名返回值，赋值给命名返回值变量；对于非命名返回值，赋值给临时变量
- 按 LIFO 执行当前函数中所有被 defer 的函数体
- 当前函数返回命名返回值变量或临时变量

### defer 性能开销

defer 本身有一定的性能开销（涉及运行时的栈操作和函数调用，约 50ns），但在大多数业务场景中可以忽略不计。对于高频调用的函数（如每秒百万次），可考虑手动管理资源，例如在 `if err != nil` 分支提前释放资源，避免 defer 的额外开销。

Go 在不同版本中对 defer 的实现进行了优化：

- Go 1.13 之前：`_defer` 结构体主要在堆上分配，这可能会带来一些性能开销
- Go 1.13：引入了在栈上分配 `_defer` 结构体的能力，减少了内存分配开销，性能提升了约 30%
- Go 1.14：进一步引入了开放编码（open-coded）的 defer。在满足特定条件（如 defer 数量不超过 8 个、未在循环中使用 defer、未在复杂的控制流中使用 defer 等）时，defer 调用会被直接展开到函数末尾，避免了创建 `_defer` 结构体，性能接近普通函数调用

```go
func example() {
    defer fmt.Println("first")   // 可能被开放编码
    defer fmt.Println("second")  // 可能被开放编码
    // ...
}

// 编译后可能展开为：
func example() {
    // 正常代码执行
    // ...
    
    // defer 被直接展开到函数末尾
    fmt.Println("second")
    fmt.Println("first")
}
```

defer 的性能一直在提升，可以放心使用，使用 defer 提升可读性是值得的。

### 常见应用场景

#### 资源释放

确保打开的文件、网络连接、数据库连接、互斥锁等资源在使用后被及时关闭，避免资源泄漏。

```go
var mu sync.Mutex

func updateData() {
 mu.Lock()
 defer mu.Unlock() // 延迟解锁（函数退出前执行）

 // 临界区代码 (可能包含 return 或 panic)
}
```

defer 中的错误容易被忽略，可以在 defer 函数体中记录错误日志或使用命名返回值传递 defer 中的错误信息。

```go
func returnError() error {
 return fmt.Errorf("return error")
}

func readFile(path string) (string, error) {
 f, err := os.Open(path)
 if err != nil {
  fmt.Printf("open file %s failed, err: %v\n", path, err)
  return "", err
 }
 // defer f.Close() // 注意：defer 中的错误容易被忽略，比如 Close 时出错。可以用下面的方式记录错误日志，但主体函数返回的错误为 nil（因为 ReadAll 没有出错），无法返回 defer 中的 Close 错误。
 defer func() {
  if errClose := f.Close(); errClose != nil { // 闭包捕获了外部变量 f
   fmt.Printf("close file %s failed, err: %v\n", f.Name(), errClose)
  }

  // 上面的 f.Close() 一般不会出错，这里用一个一定返回错误的函数做模拟
  if errSome := returnError(); errSome != nil {
   fmt.Printf("some error: %v\n", errSome)
  }
 }()

 data, err := io.ReadAll(f)
 if err != nil {
  fmt.Printf("read file %s failed, err: %v\n", f.Name(), err)
  return "", err
 }

 return string(data), nil
}

func main() {
 data, err := readFile("test.txt")                  // 需要在当前目录下创建 test.txt 文件，内容为 123
 fmt.Printf("file content: %s, err: %v\n", data, err) // 123 nil
}
```

不打印错误日志，在 defer 中修改命名返回值，向外层函数传递 defer 中的错误：

```go
func returnError() error {
 return fmt.Errorf("return error")
}

func readFile(path string) (content string, err error) {
 f, err := os.Open(path)
 if err != nil {
  fmt.Printf("open file %s failed, err: %v\n", path, err)
  return "", err
 }
 defer func() {
  var errs []error

  // 收集关闭文件时的错误
  if errClose := f.Close(); errClose != nil {
   errs = append(errs, fmt.Errorf("failed to close file: %w", errClose))
  }

  // 收集其它可能的清理错误
  if errSome := returnError(); errSome != nil {
   errs = append(errs, fmt.Errorf("cleanup error: %w", errSome))
  }

  // 如果有清理错误，合并到主错误链中
  if len(errs) > 0 {
   if err != nil {
    // 主逻辑已有错误，合并所有错误
    err = errors.Join(err, errors.Join(errs...))
   } else {
    // 主逻辑无错误，只返回清理错误
    err = errors.Join(errs...)
   }
  }
 }()

 data, err := io.ReadAll(f)
 if err != nil {
  fmt.Printf("read file %s failed, err: %v\n", f.Name(), err)
  return "", err
 }

 content = string(data)
 return
}

func main() {
 data, err := readFile("test.txt")                  // 需要在当前目录下创建 test.txt 文件，内容为 123
 fmt.Printf("file content: %s, err: %v\n", data, err) // 123 cleanup error: return error
}
```

#### 清理临时状态

例如恢复全局变量、还原标志位、重置缓存等，确保函数执行后环境不受污染。

```go
var loggingEnabled bool

// 临时启用调试模式，函数退出时恢复原始状态
func processWithDebug() {
 saved := loggingEnabled
 loggingEnabled = true
 defer func() {
  loggingEnabled = saved
 }()

 // ... 处理逻辑
}
```

#### 记录函数执行时间

使用 defer 记录函数执行时间，避免在函数体中重复编写时间记录代码。

```go
func bigSlowOperation() {
 defer trace("bigSlowOperation")() // 不要忘记末尾的括号。注意：这里会立即调用 trace 返回一个闭包，defer 的是对闭包的调用，而不是 defer trace() 本身。
 // ...lots of work…
 time.Sleep(3 * time.Second) // 模拟耗时操作
}

// 通用的 trace 函数
// 但是要在被 trace 的函数体中加一行 defer，并且要加在第一句（与装饰器模式不同，这种方式要改被 trace 的函数代码）
func trace(msg string) func() {
 start := time.Now()
 fmt.Printf("enter, msg: %s\n", msg)
 return func() {
  fmt.Printf("exit, msg: %s, duration: %v\n", msg, time.Since(start))
 }
}

func main() {
 bigSlowOperation()
}
```

#### 错误处理辅助 todo 放到 panic-recover 中？

结合 recover 捕获 panic，或在 defer 中记录错误日志，统一处理异常（见“资源释放”一节）。

```go
func safeCall(fn func()) {
 defer func() {
  if r := recover(); r != nil {
   fmt.Printf("Recovered from panic, err: %v\n", r)
   // 可以在这里进行错误上报等操作
  }
 }()
 fn()
}

func main() {
 safeCall(func() { // 函数可能 panic，在外面包装一层，捕获 panic 并恢复执行
  fmt.Println("Start")
  panic("test panic")
  fmt.Println("This line will not be executed") // 就算 recover 了，也不会执行到这一行，但匿名函数调用能正常返回
 })
 // 后续代码会继续执行
 fmt.Println("Program continues")
}
```

### defer 使用陷阱

在循环中使用 defer 要小心，可能导致资源释放不及时而耗尽。

```go
// 不好的做法
func foo() error {
 paths := [...]string{
  "/home/guang/test1.txt",
  "/home/guang/test2.txt",
  "/home/guang/test3.txt",
  // ...
 }

 for _, path := range paths {
  f, err := os.Open(path)
  if err != nil {
   return err
  }
  defer f.Close() // 所有文件在函数 foo() 结束时才会关闭，如果循环中打开了多个文件，可能会导致系统的文件描述符耗尽
  // 处理文件...
 }

 return nil
}

// 好的做法 - 在循环中使用匿名函数包一层或提取成单独函数 ProcessFile（推荐）
func bar() error {
 paths := [...]string{
  "/home/guang/test1.txt",
  "/home/guang/test2.txt",
  "/home/guang/test3.txt",
  // ...
 }

 for _, path := range paths {
  if err := func() error {
   f, err := os.Open(path)
   if err != nil {
    return err
   }
   defer f.Close() // 每次迭代都会关闭文件，因为匿名函数返回时会执行 defer 列表
   // 处理文件...

   return nil
  }(); err != nil {
   return err
  }
 }
 return nil
}
```

### os.Exit 对 defer 的影响

函数原型：`func os.Exit(code int)`，文档：<https://pkg.go.dev/os#Exit>

code 为 0 表示成功，非 0 表示错误，为了可移植性，code 范围应该为 `[0, 125]`。`os.Exit` 会使当前程序以指定的状态码退出，被 defer 的函数体将不会被执行。

```go
func main() {
 defer fmt.Println("world") // 不会被执行
 fmt.Println("hello")
 os.Exit(0)                 // 立即退出，defer 不会执行
}
// 输出：hello
```

应仅在 main 函数体中根据实际需要调用 `os.Exit`，在其它函数体中不应该调用 `os.Exit`。
