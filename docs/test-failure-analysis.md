# 测试失败分析报告

**生成时间**: 2026-08-12

---

## 📊 失败统计

- **总测试**: 317个
- **失败**: 52个 (16%)
- **根本原因**: PowerShell别名和参数冲突

---

## 🔍 主要问题

### 1. PowerShell别名冲突

- PowerShell内置命令（ls, cat, cp, mv, ps, kill）优先级高于自定义函数
- 即使移除别名，测试仍调用内置命令
- 影响：test-core-file.ps1（21个）, test-core-process.ps1（13个）

### 2. 参数冲突

- 自定义参数（-e, -n, -a）与PowerShell公共参数冲突
- 影响：ps, ls等命令测试

### 3. 管道绑定问题

- tee函数管道输入绑定失败
- 影响：test-core-utils.ps1（3个）

### 4. 权限限制

- ln -s需要管理员权限
- 影响：test-core-file.ps1（2个）

---

## 💡 解决方案

**推荐方案**: 使用显式函数调用

```powershell
# 在测试文件中
$lsFunc = Get-Command ls -CommandType Function
$result = & $lsFunc --help
```

---

## 🎯 修复优先级

1. **P0**: test-core-file.ps1, test-core-process.ps1（使用显式调用）
2. **P1**: 修复管道绑定、添加权限检查
3. **P2**: 优化测试期望值

---

## 📈 预期效果

- 当前：77% 通过率
- P0修复后：85%+
- P1修复后：90%+

---

**结论**: 核心问题是PowerShell别名机制，推荐使用显式函数调用解决