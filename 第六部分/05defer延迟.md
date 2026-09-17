# defer 延迟

defer 用于延迟执行函数调用，通常用于资源清理、锁释放、错误处理等场景。基本语法：

```go
defer 函数名(参数1, 参数2)
```

defer 的核心语义是“延迟执行”，即在当前函数的执行流程结束前，按逆序（LIFO，后进先出）执行当前函数中所有被 defer 的函数体。注意：被 defer 的函数调用，其参数会立即求值固定下来（而不是在延迟执行函数体时才计算参数），但函数体的执行会推迟到返回值求值之后、当前函数返回之前执行。

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

- 正常流程：进入当前函数 -> 执行代码 -> 遇到 return -> 计算返回值并赋值给临时变量（位于栈、寄存器或逃逸到堆上）或命名返回值变量 -> 按 LIFO 执行当前函数的 defer 列表 -> 当前函数返回（临时变量或命名返回值）
- 发生 panic 时流程：进入当前函数 -> 执行代码 -> 发生 panic -> 中断当前函数的执行 -> 按 LIFO 执行当前函数的 defer 列表 -> 如果某个被 defer 的函数体中有 `recover()`，当前函数执行完 defer 列表后直接返回（不会继续执行 panic 发生点之后的代码，返回非命名返回值类型的零值或命名返回值的值），调用当前函数的上层函数从调用点之后继续执行；否则，当前函数执行完 defer 列表后，继续将 panic 向上传播给它的调用者 -> 如果传播到当前协程的调用栈顶仍没有 `recover()` 则整个程序崩溃

Go 中 return 语句并非原子操作，它大致分为三步：

- 设置需要返回的值：对于非命名返回值，赋值给临时变量；对于命名返回值，赋值给命名返回值变量
- 按 LIFO 执行当前函数中所有被 defer 的函数体
- 当前函数返回临时变量或命名返回值变量

panic 被 recover 后会跳过 return 语句，直接返回非命名返回值类型的零值或命名返回值的值。

非命名返回值：

```go
func f() int {
 defer func() {
  if r := recover(); r != nil {
   fmt.Printf("recovered from panic, err: %v\n", r) // recovered from panic, err: f
  }
 }()

 r := 0
 panic("f")
 return r
}

func g() {
 r := f()       // f() 中的 panic 跳过了 return 语句，函数的返回值就是 int 的零值
 fmt.Println(r) // 0
}

func main() {
 g()
}
```

命名返回值：

```go
func f() (r int) {
 defer func() {
  if r := recover(); r != nil {
   fmt.Printf("recovered from panic, err: %v\n", r) // recovered from panic, err: f
  }
 }()

 r = 1
 panic("f")
 return r
}

func g() {
 r := f()       // f() 中的 panic 跳过了 return 语句，函数的返回值就是命名返回值的值
 fmt.Println(r) // 1
}

func main() {
 g()
}
```

## defer 闭包对函数返回值的影响

defer 语句本身不是闭包，当 defer 后跟匿名函数且捕获了外部变量时，就构成了闭包。

如果当前函数使用命名返回值，defer 闭包捕获了命名返回值变量，可以直接修改它们，会影响最终的返回值。

如果当前函数使用非命名返回值：

- 返回值是值类型：defer 闭包无法修改返回值，因为待返回的临时变量的赋值发生在 defer 闭包执行之前，待返回的临时变量是局部变量 `x` 的一个副本，defer 闭包修改的是局部变量 `x` 本身，不影响最终返回的临时变量
- 返回值是指针类型：defer 闭包可以修改返回值，因为待返回的临时指针变量指向的是局部变量 `x` 本身，defer 闭包修改局部变量 `x` 会影响最终的返回值
- 返回值是切片、映射等引用类型：defer 闭包可以修改返回值，因为待返回的临时“引用头”变量与局部变量 `x` 引用的是同一个底层数据，defer 闭包修改局部变量 `x` 的元素（其实修改的是底层数据）会影响最终的返回值

```go
// 命名返回值，可以在 defer 闭包中修改，影响最终的返回值
func add(x, y int) (sum int) {
 defer func() {
  sum += 10  // 修改命名返回值
 }()
 return x + y  // 执行顺序：1. 当前函数的 return 语句计算返回值并赋值给命名返回值 sum，sum=5 2. 执行被 defer 的函数体修改 sum，sum=15 3. 当前函数 return 返回 sum
}

func main() {
 fmt.Println(add(2, 3))  // 15
}
```

```go
// 指针类型的返回值，可以在 defer 闭包中修改，影响最终的返回值
func returnsPointer() *int {
 val := 10
 defer func() {
  val++  // 修改指针 &val 所指向的内存地址中的值
 }()
 // 返回局部变量 val 的地址（在 Go 中合法，val 会逃逸到堆上）
 return &val  // 执行顺序：1. 非命名返回值，将计算好的返回值，即 val 的地址赋值给临时指针变量，这个指针变量指向 val 变量本身 2. 执行被 defer 的函数体修改 val 的值，val=11 3. 当前函数 return 返回临时指针变量，即 val 的地址，其指向的值已经在 defer 中被修改了
}

func main() {
 p := returnsPointer()
 fmt.Printf("通过指针间接修改返回值：%d\n", *p)  // 11
}
```

```go
// 切片、映射等引用类型的返回值，可以在 defer 闭包中修改，影响最终的返回值
func returnsSlice() []int {
 s := []int{10}
 defer func() {
  s[0]++ // 修改切片底层数组元素
 }()
 return s // 执行顺序：1. 非命名返回值，将计算好的返回值，即 s 的“引用头”赋值给临时变量，这个变量与 s 引用的是同一个底层数组 2. 执行被 defer 的函数体修改 s 的底层数组元素，s[0]=11 3. 当前函数 return 返回临时“引用头”变量
}

func main() {
 s := returnsSlice()
 fmt.Printf("通过切片间接修改返回值：%v\n", s) // [11]
}
```

```go
// 非命名返回值，且不是指针、引用类型，无法在 defer 闭包中修改
func unnamedReturn() int {
 var result int
 defer func() {
  result++                                       // 修改的是外部变量 result，而非函数最终的返回值
  fmt.Printf("在 defer 中，局部变量 result = %d\n", result) // 11
 }()
 result = 10
 fmt.Printf("在 return 前，result = %d\n", result) // 10
 return result                              // 执行顺序：1. 非命名返回值，将计算好的返回值，即 result 的值赋值给临时变量，待返回的临时变量是 result 的一个副本，此后修改 result 不影响这个副本 2. 执行被 defer 的函数体修改 result 3. 当前函数 return 返回临时变量
}

func main() {
 fmt.Printf("非命名返回值函数结果：%d\n", unnamedReturn()) // 10
}
```

除非有明确意图（如错误传播），否则应避免在 defer 闭包中修改当前函数的返回值，被 defer 的代码仅应进行日志记录、资源清理等无副作用的操作。

## defer 性能开销

defer 的性能开销取决于编译器优化是否触发了开放编码（open-coded）机制（Go 1.14 引入）。如果满足开放编码条件，defer 的性能开销接近普通函数调用（在 Go 1.27.1 上基准测试约 2ns/op），可以放心使用；如果未触发开放编码，则涉及运行时的栈操作和函数调用，在 Go 1.13 之前可能需要约 50ns 的开销。

Go 在不同版本中对 defer 的性能进行了优化：

- Go 1.13 之前：`_defer` 结构体主要在堆上分配，这可能会带来一些性能开销
- Go 1.13：引入了在栈上分配 `_defer` 结构体的能力，减少了内存分配开销，性能提升了约 30%
- Go 1.14：进一步引入了开放编码（open-coded）的 defer。在满足特定条件（如 defer 数量不超过 8 个、没有 goto 等导致控制流不稳定的语句等）时，defer 调用会被编译器直接展开到函数末尾，避免了创建 `_defer` 结构体，性能接近普通函数调用

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

对于高频调用的函数（如每秒百万次），也可以考虑手动管理资源，例如在 `if err != nil` 分支提前释放资源，避免 defer 的额外开销。

## 常见应用场景

### 释放资源

确保打开的文件、网络连接、数据库连接、互斥锁等资源在使用后被及时关闭和释放，避免资源泄漏。

```go
var mu sync.Mutex

func updateData() {
 mu.Lock()
 defer mu.Unlock() // 延迟解锁（函数退出前执行）

 // 临界区代码 (可能包含 return 或 panic)
}
```

### 清理临时状态

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

### 记录函数执行时间

使用 defer 记录函数执行时间，避免在函数体中重复编写时间记录代码。

```go
func bigSlowOperation() {
 defer trace("bigSlowOperation")() // 不要忘记末尾的括号。注意：这里会立即调用 trace() 返回一个闭包，defer 的是对闭包的调用，而不是 defer trace() 本身。
 // ...lots of work…
 time.Sleep(3 * time.Second) // 模拟耗时操作
}

// 通用的 trace 函数
// 与装饰器模式不同，这种方式要改被 trace 的函数代码：要在被 trace 的函数体中加一行 defer，并且要加在第一句
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

## defer 中的错误处理

defer 中的错误容易被忽略，可以在 defer 函数体中记录错误日志或使用命名返回值向外层传递 defer 中的错误信息。

defer 中记录错误日志：

```go
func returnError() error {
 return fmt.Errorf("return error")
}

func createFile(path string, content string) error {
 if err := os.WriteFile(path, []byte(content), 0644); err != nil {
  fmt.Printf("failed to write %s, err: %v\n", path, err)
  return err
 }
 return nil
}
func readFile(path string) (string, error) {
 f, err := os.Open(path)
 if err != nil {
  fmt.Printf("failed to open %s, err: %v\n", path, err)
  return "", err
 }
 // defer f.Close() // 注意：defer 中的错误容易被忽略，比如 f.Close() 时出错。可以用下面的方式记录 defer 中的错误日志，但主体函数返回的错误为 nil（因为 ReadAll() 没有出错）
 defer func() {
  if errClose := f.Close(); errClose != nil { // 闭包捕获了外部变量 f
   fmt.Printf("failed to close %s, err: %v\n", path, errClose) // 记录错误日志
  }

  // 上面的 f.Close() 一般不会出错，这里用一个一定返回错误的函数做模拟
  if errSome := returnError(); errSome != nil {
   fmt.Printf("some error: %v\n", errSome) // 记录错误日志
  }
 }()

 data, err := io.ReadAll(f)
 if err != nil {
  fmt.Printf("failed to read %s, err: %v\n", path, err)
  return "", err
 }

 return string(data), nil
}

func main() {
 // 在当前目录下创建 test.txt 文件，内容为 123
 if err := createFile("test.txt", "123"); err != nil {
  return
 }

 data, err := readFile("test.txt")
 fmt.Printf("file content: %s, err: %v\n", data, err) // file content: 123, err: nil
}
```

不记录错误日志，而是在 defer 中修改命名返回值，向外层函数传递 defer 中的错误：

```go
func returnError() error {
 return fmt.Errorf("return error")
}

func createFile(path string, content string) error {
 if err := os.WriteFile(path, []byte(content), 0644); err != nil {
  fmt.Printf("failed to write %s, err: %v\n", path, err)
  return err
 }
 return nil
}

func readFile(path string) (content string, err error) { // 命名返回值
 f, err := os.Open(path)
 if err != nil {
  fmt.Printf("failed to open %s, err: %v\n", path, err)
  return "", err
 }
 defer func() {
  var errs []error

  // 收集关闭文件时的错误
  if errClose := f.Close(); errClose != nil {
   errs = append(errs, fmt.Errorf("failed to close %s, err: %w", path, errClose))
  }

  // 收集其它可能的 defer 错误
  if errSome := returnError(); errSome != nil {
   errs = append(errs, fmt.Errorf("failed to defer, err: %w", errSome))
  }

  // 如果有 defer 错误，合并到主错误链中
  if len(errs) > 0 {
   if err != nil {
    // 主逻辑已有错误，合并所有错误
    err = errors.Join(append([]error{err}, errs...)...) // 修改命名返回值
   } else {
    // 主逻辑无错误，只返回 defer 中的错误
    err = errors.Join(errs...)
   }
  }
 }()

 data, err := io.ReadAll(f)
 if err != nil {
  fmt.Printf("failed to read %s, err: %v\n", path, err)
  return "", err
 }

 content = string(data)
 return
}

func main() {
 // 在当前目录下创建 test.txt 文件，内容为 123
 if err := createFile("test.txt", "123"); err != nil {
  return
 }

 data, err := readFile("test.txt")
 fmt.Printf("file content: %s, err: %v\n", data, err) // file content: 123, err: failed to defer, err: return error
}
```

## 在循环中使用 defer 的陷阱

因为被 defer 的函数体是在当前函数 return 之前才执行，在循环中使用 defer 要小心，可能导致资源释放不及时而被耗尽。

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
  defer f.Close() // 所有文件在函数 foo() return 之前才会关闭，如果循环中打开了成千上万个文件，可能会导致系统的文件描述符耗尽
  // 处理文件...
 }

 return nil
}

// 好的做法：在循环中使用匿名函数包一层或提取成普通函数 ProcessFile（推荐）
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

func processFile(path string) error {
 f, err := os.Open(path)
 if err != nil {
  return err
 }
 defer f.Close()
 // 处理文件...
 return nil
}
```

## os.Exit() 对 defer 的影响

[func os.Exit(code int)](https://pkg.go.dev/os#Exit) 立即终止当前程序的执行并以指定的状态码 code 退出，被 defer 的函数体将不会被执行。code 为 0 表示成功，非 0 表示错误，为了可移植性，code 范围应该为 `[0, 125]`。

```go
func main() {
 defer fmt.Println("world") // 不会被执行
 fmt.Println("hello")
 os.Exit(0)                 // 立即退出，被 defer 的函数体不会被执行
}

// 输出：hello
```

应仅在 `main()` 函数体中根据实际需要调用 `os.Exit()`，在其它函数体中不应该调用 `os.Exit()`。
