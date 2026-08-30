$ErrorActionPreference = 'Stop'

$assetDir = 'D:\blog\source\_posts\20260831'
$sourceDir = 'C:\Users\ljx\Documents\Codex\2026-08-30\d-blog-post-20260831-md-d\work\latex\translate_zh_CN'
$inputMarkdown = Join-Path $assetDir '_conversion-test.md'
$referenceMarkdown = Join-Path $assetDir '_references-test.md'
$outputMarkdown = 'D:\blog\source\_posts\20260831.md'

$body = Get-Content -LiteralPath $inputMarkdown -Raw
$start = $body.IndexOf('# 引言')
$end = $body.IndexOf('# 第一Zonklar方程的证明')
if ($start -lt 0 -or $end -le $start) {
    throw 'Unable to locate the converted article boundaries.'
}
$body = $body.Substring($start, $end - $start).Trim()

# Remove the LaTeX-only figure wrappers generated before the introduction.
$body = [regex]::Replace($body, '(?ms)^::: \{\.figure\*\}\s*:::\s*', '')
$body = [regex]::Replace(
    $body,
    '(?ms)^::: \{\.figure\*\}\s*!\[image\]\(Fig/Statistics_25_7_27/Trends\.pdf\).*?^:::\s*',
    ''
)
$body = $body.Replace('工智能（AI）已进入大模型时代', '人工智能（AI）已进入大模型时代')

# Replace the TikZ/forest source and the malformed wide comparison table with web images.
$garbageStart = $body.IndexOf('=\[ rectangle')
$resumeAt = $body.IndexOf('我们的调查方法结构如下。')
if ($garbageStart -lt 0 -or $resumeAt -le $garbageStart) {
    throw 'Unable to locate the LaTeX-only introduction block.'
}
$introVisuals = @'
## 调研概览

![历年安全技术论文数量](paper-count.png)

![不同大模型类型的论文分布](model-distribution.png)

![攻击与防御类型分布](attack-defense-distribution.png)

![大模型安全研究趋势](security-research-trends.png)

![本次调查的路线图](survey-roadmap.png)

### 表 1：现有调查摘要

![现有调查摘要](table-01-existing-surveys.png)

'@
$body = $body.Substring(0, $garbageStart).TrimEnd() + "`r`n`r`n" + $introVisuals.TrimEnd() + "`r`n`r`n" + $body.Substring($resumeAt)

# Resolve citation keys and cross-references using the auxiliary file produced by LaTeX.
$aux = Get-Content -LiteralPath (Join-Path $sourceDir 'main.aux') -Raw
$citationMap = @{}
foreach ($match in [regex]::Matches($aux, '\\bibcite\{([^}]+)\}\{([^}]+)\}')) {
    $citationMap[$match.Groups[1].Value] = $match.Groups[2].Value
}
$labelMap = @{}
foreach ($match in [regex]::Matches($aux, '\\newlabel\{([^}]+)\}\{\{([^}]+)\}')) {
    $labelMap[$match.Groups[1].Value] = $match.Groups[2].Value
}

$missingCitations = [System.Collections.Generic.HashSet[string]]::new()
$body = [regex]::Replace($body, '\[@([^\]]+)\]', {
    param($match)
    $numbers = foreach ($rawKey in ($match.Groups[1].Value -split ';\s*@')) {
        $key = $rawKey.Trim().TrimStart('@')
        if ($citationMap.ContainsKey($key)) {
            $citationMap[$key]
        } else {
            [void]$missingCitations.Add($key)
            $key
        }
    }
    '[' + ($numbers -join ', ') + ']'
})

foreach ($entry in $labelMap.GetEnumerator()) {
    $label = [regex]::Escape($entry.Key)
    $number = $entry.Value
    $body = [regex]::Replace($body, '\[\\\[' + $label + '\\?\]\]\(#' + $label + '\)\{[^}]*\}', $number)
    $body = [regex]::Replace($body, '\[[^\]]+\]\(#' + $label + '\)\{[^}]*\}', $number)
    $body = [regex]::Replace($body, '\[\\\[' + $label + '\\?\]\]\{#' + $label + '[^}]*\}', $number)
}

# Replace wide LaTeX summary tables with page images in their original order.
$tableImages = @(
    '### 表 2：ViT 与 SAM 的攻击和防御总结`r`n`r`n![ViT 与 SAM 的攻击和防御总结](table-02-vfm-safety.png)',
    '### 表 3：大语言模型攻击与防御总结（一）`r`n`r`n![大语言模型攻击与防御总结（一）](table-03-llm-part-1.png)',
    '### 表 4：大语言模型攻击与防御总结（二）`r`n`r`n![大语言模型攻击与防御总结（二）](table-04-llm-part-2.png)',
    '### 表 5：大语言模型攻击与防御总结（三）`r`n`r`n![大语言模型攻击与防御总结（三）](table-05-llm-part-3.png)',
    '### 表 6：大语言模型安全数据集与基准`r`n`r`n![大语言模型安全数据集与基准](table-06-llm-datasets.png)',
    '### 表 8：视觉语言模型攻击与防御总结`r`n`r`n![视觉语言模型攻击与防御总结](table-08-vlm-safety.png)',
    '### 表 10：扩散模型攻击与防御总结（一）`r`n`r`n![扩散模型攻击与防御总结（一）](table-10-diffusion-part-1.png)',
    '### 表 11：扩散模型攻击与防御总结（二）`r`n`r`n![扩散模型攻击与防御总结（二）](table-11-diffusion-part-2.png)',
    '### 表 12：智能体攻击与防御总结（一）`r`n`r`n![智能体攻击与防御总结（一）](table-12-agent-part-1.png)',
    '### 表 13：智能体攻击与防御总结（二）`r`n`r`n![智能体攻击与防御总结（二）](table-13-agent-part-2.png)',
    '### 表 14：智能体安全基准`r`n`r`n![智能体安全基准](table-14-agent-benchmarks.png)'
)
$tablePattern = '(?ms)^::: \{\.table\*\}.*?^:::\s*'
$tableMatches = [regex]::Matches($body, $tablePattern)
if ($tableMatches.Count -ne $tableImages.Count) {
    throw "Expected $($tableImages.Count) wide tables, found $($tableMatches.Count)."
}
$builder = [System.Text.StringBuilder]::new($body)
for ($i = $tableMatches.Count - 1; $i -ge 0; $i--) {
    $replacement = $tableImages[$i].Replace('`r`n', "`r`n") + "`r`n`r`n"
    [void]$builder.Remove($tableMatches[$i].Index, $tableMatches[$i].Length)
    [void]$builder.Insert($tableMatches[$i].Index, $replacement)
}
$body = $builder.ToString()

$vlpHeading = '# 视觉-语言预训练模型安全 {#sec:vlp}'
$body = $body.Replace(
    $vlpHeading,
    $vlpHeading + "`r`n`r`n### 表 7：视觉-语言预训练模型攻击与防御总结`r`n`r`n![视觉-语言预训练模型攻击与防御总结](table-07-vlp-safety.png)"
)
$dmHeading = '# 扩散模型安全 {#sec:diffusion}'
$body = $body.Replace(
    $dmHeading,
    "### 表 9：视觉语言模型安全性与鲁棒性基准`r`n`r`n![视觉语言模型安全性与鲁棒性基准](table-09-vlm-benchmarks.png)`r`n`r`n" + $dmHeading
)

# Remove Pandoc attributes and any residual fenced Div markers.
$body = [regex]::Replace($body, '(?m)^(#{1,6}[^\r\n]*?)\s+\{#[^}\r\n]+\}\r?$', '$1')
$body = [regex]::Replace($body, '\{reference-type="ref" reference="[^"]+"\}', '')
$body = [regex]::Replace($body, '(?m)^:::\s+\{#[^}\r\n]+\}\r?$', '')
$body = [regex]::Replace($body, '(?m)^:::\s*\r?$', '')
$body = [regex]::Replace($body, '\{#[^}\r\n]+\}', '')
$body = [regex]::Replace($body, '\[\]\{style="[^"]+"\}', '')
$body = [regex]::Replace($body, '(?m)[ \t]+$', '')
$body = [regex]::Replace($body, '(\r?\n){3,}', "`r`n`r`n")

# Convert the supplied bibliography to a numbered Markdown list.
$references = Get-Content -LiteralPath $referenceMarkdown -Raw
$references = [regex]::Replace($references, '(?ms)^<div class="thebibliography">\s*100 url@samestyle\s*', '')
$references = [regex]::Replace($references, '(?ms)\s*</div>\s*$', '')
$referenceEntries = $references -split '(?:\r?\n){2,}' | Where-Object { $_.Trim() }
$numberedReferences = for ($i = 0; $i -lt $referenceEntries.Count; $i++) {
    $entry = [regex]::Replace($referenceEntries[$i].Trim(), '\s*\r?\n\s*', ' ')
    "$($i + 1). $entry"
}

$frontMatter = @'
---
title: 规模化安全：大型模型与智能体安全的综合调查
date: 2026-08-31 00:00:00
tags:
  - 人工智能安全
  - 大模型
  - 智能体
  - 论文翻译
---

> 中文翻译版。原论文：[arXiv:2502.05206](https://arxiv.org/abs/2502.05206)；配套项目：[Awesome Large Model Safety](https://github.com/xingjunm/Awesome-Large-Model-Safety)。

## 摘要

大模型的迅速发展，得益于其通过大规模预训练在学习和泛化方面表现出的卓越能力，重塑了人工智能领域的格局。本综述系统性地回顾了视觉基础模型、大语言模型、视觉-语言预训练模型、视觉-语言模型、扩散模型以及智能体的安全研究，涵盖对抗攻击、数据投毒、后门攻击、越狱与提示注入、能效-延迟攻击、数据与模型提取攻击及相应防御策略，并讨论全面安全评估、可扩展防御与全球协作等开放问题。

关键词：人工智能安全、大模型安全、智能体安全、攻击与防御。

<!-- more -->

'@

$final = $frontMatter + $body.Trim() + "`r`n`r`n# 参考文献`r`n`r`n" + ($numberedReferences -join "`r`n`r`n") + "`r`n"
Set-Content -LiteralPath $outputMarkdown -Value $final -Encoding utf8NoBOM

Write-Output "BODY_CHARS=$($body.Length)"
Write-Output "REFERENCES=$($referenceEntries.Count)"
Write-Output "MISSING_CITATIONS=$($missingCitations.Count)"
if ($missingCitations.Count -gt 0) {
    Write-Output ('MISSING_KEYS=' + (($missingCitations | Sort-Object) -join ','))
}
RS=$($body.Length)"
Write-Output "REFERENCES=$($referenceEntries.Count)"
Write-Output "MISSING_CITATIONS=$($missingCitations.Count)"
if ($missingCitations.Count -gt 0) {
    Write-Output ('MISSING_KEYS=' + (($missingCitations | Sort-Object) -join ','))
}
