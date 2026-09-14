# range 迭代与 iter 包

`range` 是 Go 的关键字，不是函数。`range` 提供了一种简洁、统一的方式来迭代各种集合类型的数据结构，包括字符串、数组、切片、映射、通道等。

| 对象 | 语法 | 返回内容 | 关键特性与注意事项 |
| -- | -- | -- | -- |
| 数组 | `for i, v := range a` | 元素的索引 `i`（从 0 开始）和值 `v`（副本） | 循环次数在迭代开始时就确定了，中途不会改变。注意：1. `v` 是元素的副本，修改它不影响原数组 2. `range a` 迭代的是 a 的一个副本，会拷贝整个数组（因为数组是值类型），对于大型数组应使用 `range &a` 或 `range a[:]`，以减少拷贝开销 |
| 切片 | `for i, v := range s` | 元素的索引 `i`（从 0 开始）和值 `v`（副本） | 循环次数在迭代开始时就确定了，中途不会改变。注意：1. `v` 是元素的副本，修改它不影响原切片 2. `range s` 迭代的是 s 的一个副本，在循环中对 s 的修改（如增删元素）不会影响迭代结果 3. 对 `nil` 切片执行 range 是安全的，迭代次数为 0 |
| 映射 | `for k, v := range m` | 键 `k`，值 `v`（副本） | 迭代顺序是随机的（Go 有意为之），但在迭代开始时就确定了。注意：1. `v` 是值的副本，修改它不影响原映射 2. 虽然 `range m` 迭代的也是 m 的一个副本，但副本与 m 指向同一个底层哈希表，且迭代器能正确处理哈希表扩容，所以可以忽略副本行为带来的影响 3. 对 `nil` 映射执行 range 是安全的，迭代次数为 0 |
| 字符串 | `for i, r := range s` | rune 字符的起始字节在字符串底层字节序列的偏移量 `i`（从 0 开始），完整的 rune 字符 `r`（副本） | 能够正确处理 UTF-8 编码，识别一个个多字节编码 Unicode 的字符。注意：1. `r` 是字符的副本，修改它不影响原字符串 2. 虽然 `range s` 迭代的也是 s 的一个副本，但字符串的拷贝开销很小（仅拷贝底层字节数组指针和长度 len 两个字段），且字符串是不可变类型，所以可以忽略副本行为带来的影响 |
| 通道 | `for v := range c` | 接收到的值 `v` | `range` 迭代会持续从通道中读取数据，直到通道被显式关闭才会退出循环，并在退出前接收完通道中的所有数据；如果通道为 `nil` 或为空，则阻塞等待 |

在迭代之前，`range` 关键字会对它后面的表达式先求值，再拷贝求值结果，然后在这个副本（快照）上进行迭代。这是 `range` 迭代的一个非常关键的行为。

数组是值类型，`range a` 会拷贝整个数组（包括所有元素），然后在这个拷贝上迭代。对于大型数组，这个拷贝开销很大，应使用 `range &a` 或 `range a[:]`，以减少拷贝开销。

```go
func main() {
 a := [5]int{1, 2, 3, 4, 5}

 for i, v := range a {
  a[i] = a[i] * 2       // 修改原数组
  fmt.Printf("%v\t", v) // 输出 1 2 3 4 5  --迭代结果不受影响，因为 range 是在数组的一个副本上做迭代
 }
 fmt.Println()

 fmt.Println(a) // [2 4 6 8 10]
}
```

## 忽略索引/键、值

索引/键、值（副本）可赋值给空白标识符 `_` 以忽略：

```go
func main() {
 var a []int = []int{1, 2, 3}

 for i, _ := range a {
 }

 for _, v := range a {
 }
}
```

只想要索引/键时，可省略第二个变量。

```go
for i := range a {
}
```

## 副本的开销

每次循环中，索引/键、值（副本）都是不同的变量。

```go
type user struct {
 A   int
 B   string
 big [1024 * 1024]byte
}

func main() {
 users := []user{
  {A: 1, B: "one"},
  {A: 2, B: "two"},
 }

 for i, u := range users { // u 是元素副本，range 在“切片头”的副本上迭代
  fmt.Printf("%p\n", &i)                // 每次循环中 i 的地址都不同
  fmt.Printf("%p, %p\n", &u, &users[i]) // 每次循环中 u 的地址都不同，u 和 users[i] 的地址也不同，是不同的变量
 }
}
```

从以上输出可以发现：

1. 每次循环中变量 i、u 的地址都是不同的（Go 1.22 引入的 per-iteration 变量语义），这解决了此前循环变量被闭包捕获时的意外共享问题
2. 变量 u 的地址与 users 切片中元素的地址都不相同，说明 u 是一个副本，如果结构体中含有较大 size 的字段（如示例中的 big 字段），复制这个副本的代价就比较大

优化思路：

- 在循环中通过索引 `users[i]` 直接访问切片元素，不使用副本 u
- 将元素为值类型的切片 `[]user` 改为元素为指针类型的切片 `[]*user`。

## 遍历数组、切片

`range` 迭代遍历数组、切片时，每次循环都会返回两个值：索引和对应索引元素的副本，索引从 0 开始。需要注意：遍历获取的 v 是元素的副本，修改它不会影响原数组/切片。如果需要修改原数组/切片，应通过索引 `s[i]` 直接访问数组/切片元素。

```go
func main() {
 var pow = []int{1, 2, 4, 8, 16, 32, 64, 128}

 // range 遍历数组、切片时，每次迭代都会返回两个值：索引和对应索引元素的副本
 for i, v := range pow { // v 是副本
  fmt.Printf("2**%d = %d\n", i, v)
 }

 nums := []int{1, 2, 3}
 for _, num := range nums { // num 是副本
  num = num * 2 // 修改副本 num，原切片 nums[i] 不受影响
 }
 fmt.Println(nums) // [1 2 3]

 for i, _ := range nums {
  nums[i] = nums[i] * 2 // 这样才能修改原切片
 }
 fmt.Println(nums) // [2 4 6]
}
```

`range` 迭代遍历数组、切片时，循环次数在开始时就确定了。在迭代之前，`range` 关键字会对它后面的表达式求值一次，确定被遍历对象（数组/切片的一个副本）的长度 n，然后就固定循环 n 次。无论循环体中对原数组/切片做了什么操作（修改元素、追加或删除元素），都不会改变已经确定的循环次数和迭代结果。

```go
func main() {
 s := []int{1, 2, 3}
 fmt.Printf("初始长度：%d\n", len(s)) // 3

 for i, v := range s { // range 迭代的是 s 的一个副本，循环体中对 s 的修改不会影响迭代结果。只会循环 3 次，循环次数在迭代开始时就确定了，不会改变
  fmt.Printf("迭代 %d: v=%d, 当前长度=%d, 当前切片=%v\n", i, v, len(s), s)

  if i == 0 {
   s = slices.Insert(s, 0, []int{4, 5, 6}...) // 在头部插入 3 个元素，切片长度增加 3
   fmt.Printf("插入后长度：%d\n", len(s))           // 6
  }

  if i == 1 {
   s = s[:len(s)-1]                 // 收缩 1 个元素，切片长度减 1
   fmt.Printf("删除后长度：%d\n", len(s)) // 5
  }
 }

 fmt.Printf("最终的切片=%v\n", s) // [4 5 6 1 2]
}

// 初始长度：3
// 迭代 0: v=1, 当前长度=3, 当前切片=[1 2 3]
// 插入后长度：6
// 迭代 1: v=2, 当前长度=6, 当前切片=[4 5 6 1 2 3]
// 删除后长度：5
// 迭代 2: v=3, 当前长度=5, 当前切片=[4 5 6 1 2]
// 最终的切片=[4 5 6 1 2]
```

```go
func main() {
 s := []int{1, 2, 3}
 fmt.Printf("初始长度：%d\n", len(s)) // 3

 for i, v := range s { // range 迭代的是 s 的一个副本，循环体中对 s 的修改不会影响迭代结果。只会循环 3 次，循环次数在迭代开始时就确定了，不会改变
  fmt.Printf("迭代 %d: v=%d, 当前长度=%d, 当前切片=%v\n", i, v, len(s), s)

  s = s[:len(s)-1] // 收缩 1 个元素，切片长度减 1
  fmt.Printf("删除后长度：%d\n", len(s))
 }

 fmt.Printf("最终的切片=%v\n", s) // []
}

// 初始长度：3
// 迭代 0: v=1, 当前长度=3, 当前切片=[1 2 3]
// 删除后长度：2
// 迭代 1: v=2, 当前长度=2, 当前切片=[1 2]
// 删除后长度：1
// 迭代 2: v=3, 当前长度=1, 当前切片=[1]
// 删除后长度：0
// 最终的切片=[]
```

应当避免在遍历切片的过程中增删元素，因为可能导致切片扩容，使得迭代结果难以理解。

## 循环 N 次新语法

Go 1.22+ 扩展了语言规范，支持 `for range N` 语法，它会创建一个从 `[0, N)` 范围的循环，即循环 N 次。

下表对比了新旧写法，可以清晰地看到新语法带来的简洁性：

| 特性 | 传统写法 | Go 1.22+ 新写法 |
| -- | -- | -- |
| 循环 N 次，不关心索引 | `for i := 0; i < N; i++ { // 不关心 i }` | `for range N { // 不关心 i }` |
| 需要使用索引 | `for i := 0; i < N; i++ { // 使用 i }` | `for i := range N { // 使用 i }` |

## iter 包

随着 Go 1.23 的发布，语言对迭代器提供了原生支持，通过 [iter](https://pkg.go.dev/iter) 包和 range-over-func 特性，使得编写和使用迭代器变得更加简洁统一。

基本语法：`for range f`，其中 `f` 是 `iter` 包中定义的迭代器类型 `Seq`（单值迭代器函数）或 `Seq2`（双值迭代器函数）。

```go
type Seq[V any] func(yield func(V) bool)
type Seq2[K, V any] func(yield func(K, V) bool)
```

函数参数 `yield` 并不是一个内置的关键字或语句（不像 Python 或 C# 中的 `yield return`），它只是一个约定俗成的函数参数名字。

`yield` 函数体 `func(v V) bool {...}` 是编译器自动生成的，在 `for range` 运行时传给 `yield` 参数，其作用是向 `for range` 循环体推送一个/对元素。

- 当 `for range` 循环的一次迭代正常执行完毕（没有 break/return/goto），准备进入下一次迭代时，`yield` 函数体返回 `true`
- 当 `for range` 循环提前结束时（break/return/goto），`yield` 函数体返回 `false`
  
Go 迭代器的标准样板代码：

```go
func 迭代器名(参数...) iter.Seq[元素类型] {
    return func(yield func(元素类型) bool) {
        // 产生数据
        for ... {
            if !yield(元素) {
                return   // 调用方终止，立即退出
            }
        }
    }
}
```

迭代器内部通过调用 `yield(v)` 产生每个/对元素。如果 `yield` 返回 `true`，表示 `for range` 循环希望继续接收下一个/对元素；如果返回 `false`，表示即将退出 `for range` 循环，迭代器应立即停止产生后续元素并返回。

基本示例：

```go
// 定义一个生成 0~n-1 的迭代器
func countTo(n int) iter.Seq[int] {
 return func(yield func(int) bool) {
  for i := range n {
   if !yield(i) {
    return // 如果 yield 返回 false，迭代器应立即停止产生后续元素并返回
   }
  }
 }
}

func main() {
 // 使用 for range 遍历自定义迭代器
 for v := range countTo(5) {
  if v == 2 {
   break // break 让编译器生成的 yield 函数体返回 false，触发迭代器内部的 return
  }
  fmt.Println(v) // 0, 1
 }
}
```

### 链式过滤与映射操作

```go
// 过滤：只返回满足条件的元素
func filter[V any](seq iter.Seq[V], fn func(V) bool) iter.Seq[V] {
 return func(yield func(V) bool) {
  for v := range seq {
   if fn(v) {
    if !yield(v) {
     return
    }
   }
  }
 }
}

// 映射：对每个元素进行变换
func mapValues[V, W any](seq iter.Seq[V], fn func(V) W) iter.Seq[W] {
 return func(yield func(W) bool) {
  for v := range seq {
   if !yield(fn(v)) {
    return
   }
  }
 }
}

func main() {
 nums := countTo(10)                                           // 0~9
 evens := filter(nums, func(n int) bool { return n%2 == 0 })   // 0, 2, 4, 6, 8  --偶数
 doubled := mapValues(evens, func(n int) int { return n * 2 }) // 0, 4, 8, 12, 16  --偶数的两倍

 for v := range doubled {
  fmt.Println(v) // 0, 4, 8, 12, 16
 }
}
```

### Pull 模式

前面介绍的 `Seq[V]` 采用的是 Push 模式，即迭代器内部通过 `yield` 主动将元素“推”给 `for range` 循环体。在某些场景下，我们希望在循环外部手动拉取元素，例如：

- 需要按需获取单个元素，而非一次性遍历整个序列
- 需要交错地从多个迭代器中拉取数据
- 需要在迭代过程中暂停和恢复

[func Pull[V any](seq Seq[V]) (next func() (V, bool), stop func())](https://pkg.go.dev/iter#Pull) 可将 Push 迭代器转换为 Pull 模式，返回两个函数：

- `next()` 每调用一次取一个值，返回 `(值, 是否有效)`；序列耗尽或调用 `stop()` 函数后， `next()` 将一直返回 `(零值, false)`
- `stop()` 提前结束迭代，释放迭代器资源，官方建议 `defer stop()`

[func Pull2[K, V any](seq Seq2[K, V]) (next func() (K, V, bool), stop func())](https://pkg.go.dev/iter#Pull2) 是 `Seq2` 版本，`next()` 一次取一对 `(K, V, bool)`。

注意：不能从多个协程并发调用 `next()`/`stop()`。

```go
func main() {
 seq := countTo(5)
 next, stop := iter.Pull(seq)
 defer stop()

 for {
  v, ok := next()
  if !ok { // 序列耗尽或调用 stop() 函数后，next() 将一直返回 (零值，false)
   break
  }

  fmt.Printf("%v ", v) // 0 1 2 3 4
 }
}
```
