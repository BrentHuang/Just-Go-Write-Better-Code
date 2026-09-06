## rand 随机数

### 通用伪随机数

从 Go 1.22 开始，官方推荐使用 [math/rand/v2](https://pkg.go.dev/math/rand/v2#pkg-overview)，它在性能和易用性上做了改进。新版本中，全局生成器默认自动使用随机种子，无需手动初始化。`math/rand/v2` 包提供了丰富的函数：

| 函数 | 描述 | 示例 |
| -- | -- | -- |
| `IntN(n int) int` | 返回 `[0, n)` 内的随机整数 | `rand.IntN(100)` |
| `Int() int` | 返回一个非负的随机整数 | `rand.Int()` |
| `Float64() float64` | 返回 `[0.0, 1.0)` 内的随机浮点数 | `rand.Float64()` |
| `Perm(n int) []int` | 返回 n 个元素的切片，每个元素都是 `[0, n)` 内的随机整数 | `rand.Perm(3)` |
| `Shuffle(n int, swap func(i, j int))` | 随机打乱切片中元素的顺序，n 表示元素的个数，swap 函数则用于交换切片中索引为 i 和 j 的元素 | `rand.Shuffle(len(s), f)` |

```go
func main() {
 for _, value := range rand.Perm(5) { // Perm 是 Permutation 的缩写，指数学中的”排列“
  fmt.Println(value)
 }

 words := strings.Fields("ink runs from the corners of my mouth") // 按空白字符分割字符串，返回一个字符串切片
 rand.Shuffle(len(words), func(i, j int) {
  words[i], words[j] = words[j], words[i]
 })
 fmt.Println(words)
}
```

如果需要一个可重现的随机序列（比如用于测试），可以自己创建生成器并指定种子：

```go
func main() {
 // 用两个 uint64 数作为种子创建一个 PCG 源。PCG 是 Permuted Congruential Generator（排列同余生成器）的缩写，是一种 伪随机数生成算法。
 s := rand.NewPCG(42, 1024) // 42 和 1024 是两个 uint64 种子值，决定生成序列的起始状态。相同种子 -> 相同序列，因此每次运行都会输出 94、49
 r := rand.New(s)           // 创建一个随机数生成器

 // 每次运行都会产生相同的序列
 fmt.Println(r.IntN(100)) // 94
 fmt.Println(r.IntN(100)) // 49
}
```

### 安全随机数

如果你的应用涉及密码、令牌、API 密钥、CSRF 令牌等安全敏感场景，必须使用 [crypto/rand](https://pkg.go.dev/crypto/rand#pkg-overview) 包。它利用操作系统底层的加密安全随机数生成器（CSPRNG），生成的随机数不可预测。

生成随机字节切片：

```go
func main() {
 // 创建一个长度为 16 的字节切片
 b := make([]byte, 16)
 // 从加密安全的随机源读取字节填充切片
 _, err := rand.Read(b)
 if err != nil {
  panic(err)  // 这里仅为示例，在实际代码中应妥善处理错误
 }
 fmt.Printf("随机字节：%x\n", b)  // 例如：8f6e7a9b...
}
```

生成指定范围的随机整数 (`crypto/rand.Int`)：

```go
func main() {
 // 生成一个 [0, 100) 内的随机整数
 n, err := rand.Int(rand.Reader, big.NewInt(100))
 if err != nil {
  panic(err)
 }
 fmt.Printf("安全随机数：%d\n", n)
}
```

> [!TIP]
> `math/rand/v2` 包的顶层函数（如 `Intn`/`IntN`）是 Goroutine-Safe 的。但自己创建的 `*rand.Rand` 实例不是 Goroutine-Safe 的，需要加锁或避免共享。`crypto/rand.Reader` 是 Goroutine-Safe 的。
> `math/rand/v2` 性能极高，适合高性能场景。`crypto/rand` 因涉及系统调用，性能开销较大，应仅在需要时使用。
