# for range 遍历、迭代器

range 是 Go 的关键字，不是函数。range 提供了一种简洁、统一的方式来迭代遍历各种集合类型的数据结构，包括字符串、数组、切片、Map、通道等。

| 对象 | 语法 | 返回内容 | 关键特性与注意事项 |
| -- | -- | -- | -- |
| 字符串 | `for i, r := range s` | rune 字符的起始字节在字符串底层字节序列的偏移量 `i`，完整的 rune 字符 `r`（副本） | 能够正确处理 UTF-8 编码，识别一个个多字节编码的字符。注意：`r` 是字符的副本，修改它不会影响原数据 |
| 数组、切片 | `for i, v := range s` | 元素的索引 `i` 和值`v`（副本） | 循环次数在开始时就确定了。注意：`v` 是元素的副本，修改它不会影响原数据 |
| map | `for k, v := range m` | 键 `k`，值 `v`（副本） | 遍历顺序是不固定的（Go 有意为之），但在循环开始时就确定了。注意：`v` 是值的副本，修改它不会影响原数据 |
| 通道 | `for v := range c` | 接收到的值 `v` | 会持续从通道中读取数据，直到通道被关闭后才会结束循环。如果通道为空，则会阻塞等待 |

索引/键或值可赋给空白标识符 `_` 以忽略：

```go
func main() {
 var nums []int = []int{1, 2, 3}

 for i, _ := range nums {
 }

 for _, v := range nums {
 }
}
```

只想要索引/键时，可省略第二个变量。

```go
for i := range nums {
}
```

## 遍历数组、切片

for range 遍历数组、切片时，每次迭代都会返回两个值：索引和对应索引元素的副本，索引从 0 开始。需要注意：遍历获取的 v 是元素的副本，修改它不会影响原数据。如果需要修改原数据，应通过索引直接访问。

```go
func main() {
 var pow = []int{1, 2, 4, 8, 16, 32, 64, 128}

 // range 遍历数组、切片时，每次迭代都会返回两个值：索引和对应索引元素的副本
 for i, v := range pow {
  fmt.Printf("2**%d = %d\n", i, v)
 }

 nums := []int{1, 2, 3}
 for _, num := range nums {
  num = num * 2 // 这只修改了副本 num，nums[i] 不变
 }
 fmt.Println(nums) // [1 2 3]

 for i, _ := range nums {
  nums[i] = nums[i] * 2 // 这样才能修改原切片元素
 }
 fmt.Println(nums) // [2 4 6]
}
```

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

 for i, u := range users {
  fmt.Printf("%p\n", &i)                // 每次循环中 i 的地址都不同
  fmt.Printf("%p, %p\n", &u, &users[i]) // 每次循环中 u 的地址都不同，u 和 users[i] 的地址也不同，是不同的变量
 }
}

// 输出：
// 0x90c41602000, 0x90c41400000
// 0x90c41704000, 0x90c41500018
```

从以上输出可以发现：

1. 每次 for range 循环中变量 i、u 的地址都是不同的，见“闭包捕获循环变量”一节
2. 变量 u 的地址与 users 切片中元素的地址都不相同，说明 u 是一个副本，如果结构体中含有较大 size 的字段（如示例中的 big），复制副本的代价就比较大

优化思路：在 for range 循环中通过索引访问切片元素，或者将值切片 `[]user` 修改为指针切片 `[]*user`。

for range 遍历数组、切片时，循环次数在开始时就确定了。Go 在进入循环体之前，会把 range 后面的表达式求值一次，确定被遍历对象的长度 n。然后循环就固定迭代 n 次，无论循环体中对原始切片做什么操作（追加、删除等），都不会改变已经确定的循环次数。

```go
func main() {
 s := []int{1, 2, 3}
 fmt.Printf("初始长度：%d\n", len(s)) // 3

 for i, v := range s { // 只循环 3 次
  fmt.Printf("迭代 %d: v=%d, 当前长度=%d\n", i, v, len(s))

  // 在循环中修改切片长度
  if i == 0 {
   s = append(s, 4, 5, 6) // 追加 3 个元素，切片长度增加 3
   fmt.Printf("追加后长度：%d\n", len(s)) // 6
  }

  if i == 2 {
   s = s[:len(s)-1]              // 收缩 1 个元素，切片长度减 1
   fmt.Printf("删除后长度：%d\n", len(s)) // 5
  }
 }

 fmt.Printf("%v\n", s) // [1 2 3 4 5]
}

// 输出：
// 初始长度：3
// 迭代 0: v=1, 当前长度=3
// 追加后长度：6
// 迭代 1: v=2, 当前长度=6
// 迭代 2: v=3, 当前长度=6
// 删除后长度：5
// 最终切片： [1 2 3 4 5]
```

应当避免在遍历切片时添加元素。

## 遍历切片时删除元素

遍历切片时删除元素，最常见的错误是正序遍历直接删除（元素前移导致还未遍历的高索引区域的元素索引发生变化，可能漏删或越界）。正确做法是倒序遍历删除（元素前移只影响已经遍历的高索引区域，不影响还未遍历的低索引区域），或使用辅助切片存储要保留的元素。

```go
// 倒序遍历切片过程中删除元素的原理：
// 遍历方向：从切片的高索引（尾部）向低索引（头部）移动，即索引值递减
// 元素移动方向：当删除当前元素时，其后方的元素（更高索引位的元素）会向前移动（向低索引方向移动）以填补空缺
// 由于遍历是从后向前的，任何因删除而发生的元素前移，都只会影响已经遍历的“后方”区域（即更高索引位的元素），而不会影响尚未遍历的“前方”区域（即更低索引位的元素）
// 因为遍历指针已经检查过高索引区域，并且正在向低索引移动，元素的前移发生在“身后”，所以不会干扰后续的遍历过程
func removeElementsReverse(s []int, v int) []int {
 for i := len(s) - 1; i >= 0; i-- {
  if s[i] == v {
   s = append(s[:i], s[i+1:]...)
  }
 }
 return s
}

// 快慢指针法（过滤法）
func removeElementsFilter(s []int, v int) []int {
 j := 0
 for _, val := range s {
  if val != v {
   s[j] = val
   j++
  }
 }
 return s[:j]
}

// 临时切片法（创建新切片）
func removeElementsNewSlice(s []int, v int) []int {
 result := make([]int, 0, len(s)-1)
 for _, val := range s {
  if val != v {
   result = append(result, val)
  }
 }
 return result
}

func main() {
 // 使用示例
 nums := []int{1, 2, 3, 4, 5, 3}
 nums = removeElementsReverse(nums, 3)
 fmt.Println(nums) // 输出：[1 2 4 5]

 nums = []int{1, 2, 3, 4, 5, 3}
 nums = removeElementsFilter(nums, 3)
 fmt.Println(nums) // 输出：[1 2 4 5]

 nums = []int{1, 2, 3, 4, 5, 3}
 nums = removeElementsNewSlice(nums, 3)
 fmt.Println(nums) // 输出：[1 2 4 5]
}
```

## 循环 N 次新语法

Go 1.22+ 扩展了语言规范，支持 `for range integer_constant` 这种语法，它会创建一个从 `[0,integer_constant - 1)` 范围的循环，即循环 integer_constant 次。

下面这个表格对比了新旧写法，可以清晰地看到新语法带来的简洁性：

| 特性 | 传统写法 | Go 1.22+ 新写法 |
| -- | -- | -- |
| 循环 N 次 | `for i := 0; i < N; i++ { // 不关心 i }` | `for range N { // 不关心 i }` |
| 需要索引 | `for i := 0; i < N; i++ { // 使用 i }` | `for i := range N { // 使用 i }` |

## 迭代器 iter 包

随着 Go 1.23 版本的发布，语言对迭代器提供了原生支持，通过 iter 包和 range-over-func 特性，使得编写和使用迭代器变得更加简洁统一。

基本语法：`for range f`，其中 `f` 是一个签名为 `func(yield func(V) bool)` 的单值迭代器函数或 `func(yield func(K, V) bool)` 的双值迭代器函数，或使用标准库 `iter` 包定义的迭代器。

iter 包（Go 1.23 新增）：

```go
type Seq[V any] func(yield func(V) bool)
type Seq2[K, V any] func(yield func(K, V) bool)
```

yield 并不是一个内置的关键字或语句（不像 Python 或 C# 中的 yield return），它只是一个约定俗成的函数参数名称，用于 Go 1.23 引入的 iter 包和 range-over-func 特性中。

迭代器内部通过调用 `yield(v)` 来产生每个元素。如果 yield 返回 true，表示循环希望继续接收下一个元素；如果返回 false，表示循环已经终止（例如执行了 break 或 return），迭代器应立即停止产生后续元素并返回。

基本示例：

```go
// 定义一个生成 0 到 n-1 的迭代器
func countTo(n int) iter.Seq[int] {
    return func(yield func(int) bool) {
        for i := 0; i < n; i++ {
            if !yield(i) {
                return // 如果 yield 返回 false，停止迭代
            }
        }
    }
}

func main() {
    // 使用 for range 遍历自定义迭代器
    for v := range countTo(5) {
        fmt.Println(v) // 0, 1, 2, 3, 4
    }
}
```

过滤链式操作：

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
    nums := countTo(10)
    evens := filter(nums, func(n int) bool { return n%2 == 0 })
    doubled := mapValues(evens, func(n int) int { return n * 2 })

    for v := range doubled {
        fmt.Println(v) // 0, 4, 8, 12, 16
    }
}
```

与 maps、slices 包配合（Go 1.23 新增迭代器方法）：

```go
func main() {
 m := map[string]int{"a": 1, "b": 2, "c": 3}

 // maps.All 返回 iter.Seq2，可以直接 for range 遍历
 for k, v := range maps.All(m) {
  fmt.Printf("%s: %d\n", k, v)
 }

 // slices.All 返回 iter.Seq2[int, V]
 s := []string{"hello", "world"}
 for i, v := range slices.All(s) {
  fmt.Printf("%d: %s\n", i, v)
 }
}
```

Pull 模式（iter.Pull / iter.Pull2）：

```go
func main() {
 seq := countTo(5)
 next, stop := iter.Pull(seq)
 defer stop()

 for {
  v, ok := next()
  if !ok {
   break
  }
  fmt.Println(v)
 }
}
```
