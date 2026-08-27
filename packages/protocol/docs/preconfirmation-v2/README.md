# Taiko 预确认协议 v2 —— Slot-Chain（槽位签名链）设计

本目录是预确认协议的**当前设计线（v2）**。

## 背景

此前的 v15 设计线采用单一席位持有者（seat holder）独占排序的模型，经十余轮评审
收敛。所有者随后提出活性（liveness）批评并给出新方向：把区块构建下放给按 slot
轮换的构建者（builder）集合、席位收缩为聚合/落地服务；随后的七维度对抗性评估确认
该方向唯一但真实的收益是亚 epoch 级（sub-epoch）故障切换。所有者确认亚 epoch 级
切换为产品需求，并给出两项关键机制修复（签名串联父块哈希；随机数只取 L1 数据），
于是有了本设计线。v15 全文、评审记录与评估文档保留在 git 历史中；值得保留的结论
摘录于 [`legacy-summary.md`](legacy-summary.md)。

## 内容

| 文档 | 说明 |
| --- | --- |
| [`slot-chain-spec.md`](slot-chain-spec.md) | **主规范（草案 v1.50，中文，规范性来源，含 10 幅图与排班表可执行代码）**——可读的排版版本见下方 PDF。核心机制：1 秒一个 slot 的构建者排班表（lookahead）、逐块签名并以父块哈希串联的签名链（signature chain）、原子落地 + 结算窗口最终性（数据 + 有效性证明一笔交易落为候选,窗口内最重已证明候选收盘即最终,option C）、基于 L1 可观测滞后量（lag）的无许可兜底落地与失职计次（聚合者无论掉线还是恶意拖延都不是活性单点）、逐块电路强制的强制包含（forced inclusion，任意密钥仅强制块逃生阀）、双签的 L1 直接验签罚没（窗口累积敞口定价）。相对 v15 删除了 EBC/epoch 判定、默认派生、完全无政府模式与取消级联等整套机制；§9 的活性核算表给出各角色（含 Byzantine 聚合者）故障下的恢复界。 |
| [`slot-chain-spec.en.md`](slot-chain-spec.en.md) | **主规范的英文版**，也是 PDF 的排版输入。**非规范性**：两版有出入时以中文版为准。文件头记录翻译时中文源的 sha256；改了中文源就必须重译并更新该标记，否则 `python3 build-pdf.py --check` 报漂移（防止 PDF 静默停在旧语义上）。 |
| [`settlement-window-model.py`](settlement-window-model.py) | **结算窗口可执行参考模型**（零依赖 Python）：§5.2 全序 key、§5.6 窗口状态机、§7/§8 双约束游标 + 时序几何/罚没时点/兜底快照/窗口中途入队的可运行版本，21 项性质断言（P1–P12，附录 C；时序参数为独立声明的部署值，P9a 以不等式互检——不由公式推导，保持检验力）。改规则必须同步改模型重跑。 |
| [`lookahead-model.py`](lookahead-model.py) | **排班表可执行参考实现**（零依赖 Python，§3.2 代码化）：窗口对齐/唯一快照/种子/加权抽样的完整计算 + 6 项性质断言；抽样算子为 §12-18(b) 定形候选。 |
| [`settlement-window-RESULTS.md`](settlement-window-RESULTS.md) | 模型验证结果（P1–P12 共 21 项全过）与覆盖对照。 |
| [`settlement-window-implementation-review.md`](settlement-window-implementation-review.md) | **实现前复核（§12 第 18 项后半,r44）**：模型未覆盖项闭合对照、Solidity 级 `acceptCandidate` 存储布局（固定 4 词复用）与 gas 分析（边际 O(1),≈20–25k/候选）、Inbox 对接路径、仍开放项清单。非规范性;最终判定 = 所有者 + 人类安全评审。 |
| [`slot-chain-spec.pdf`](slot-chain-spec.pdf) | **主规范的 PDF 版**（英文、A4 单栏、学术论文式排版，90 页）：标题页 + 摘要 + 目录，正文与公式统一用 Palatino（`mathpazo`），10 幅 TikZ 灰阶图，§/附录交叉引用可点击，评审出处注记集中在附录 E。由 `build-pdf.py` 从 `slot-chain-spec.en.md` 生成，**刻意输出为 PDF 1.4**（经典 xref 表 + `trailer`，不用对象流/交叉引用流）——PDF 1.5 结构小约 28%，但只实现 1.4 的老解析器（不少电子书阅读器、电纸书固件）会误报"文件已损坏"。 |
| [`build-pdf.py`](build-pdf.py) | PDF 生成器（`slot-chain-spec.en.md` → LaTeX → PDF）。改 md 后运行 `python3 build-pdf.py` 重新生成并提交；`python3 build-pdf.py --check` 跑两道漂移防护——英文版是否落后于中文规范源（比对头部 sha256）、`tex/main.tex` 是否落后于英文版。需要 `texlive-xetex texlive-latex-extra texlive-pictures`（v1.49 起不再依赖 `texlive-lang-chinese`；生成器调 `xelatex`，`pdflatex` 也能直接编译 `tex/main.tex`）。 |
| [`tex/main.tex`](tex/main.tex) / [`tex/figures.tex`](tex/figures.tex) | 论文的 LaTeX 源：`main.tex` 由生成器从 markdown 产出（一并入库，便于不装生成器也能直接编译审阅），`figures.tex` 是手写的 10 幅 TikZ 灰阶图源。编译中间件（aux/log/toc/out）不入库。 |
| [`legacy-summary.md`](legacy-summary.md) | 既往工作摘要（非规范性）：v15 线一段话、保留的关键结论（v15 活性事实、强制包含不可删的论证、拆分评估的坑与 v2 解法对照、在线核实过的外部先例）、原始文档的 git 历史索引。 |

## 状态

草案 v1.50（2026-08-27）：修一处陈旧加粗小标题。§5.2 末条要点的小标题仍写着"落地『该落哪条』
是可罚没的义务"——那是 v1.39/v1.40 挑战层的残留，与**它自己那条要点的正文**、§5.2 上文 v1.47 的
定性、以及 §10 的罚没清单三处冲突（option C 早已撤回"落错链可罚没"）。改为"L1 不裁决『该落哪条』，
由结算窗口机械选出"。纯一致性修订，无新规则、无参数变动。
v1.49（2026-08-27）：论文改为英文版。新增 `slot-chain-spec.en.md`（中文版的完整英译，
分八段并行翻译、共用一份由附录 B 导出的术语表，行内标识符/§ 引用/列表层级/表格结构逐项对源核对），
PDF 改由该文件生成：文档类 `ctexart` → `article`，字体换成 Palatino（`mathpazo`，正文与公式同族）
配 `microtype`，去掉 CJK 字体依赖；补 26 个 Unicode 符号映射与全角标点归一化；10 幅 TikZ 图的
标签与图注全部英化并按英文宽度（约为中文的 1.6–2 倍）重调，xelatex 与 pdflatex 双引擎验证
零 overfull、零缺字。规范语义、参数、两个可执行模型均未改动。**中文版仍是规范性来源**，
同步靠英文版头部的 sha256 标记 + `build-pdf.py --check`。
v1.48（2026-08-27）：排版线改为 LaTeX——新增单栏学术论文式 PDF（`build-pdf.py`，68 页），
10 幅图重画为 TikZ 灰阶图，约 310 处评审出处注记外置为附录 E 的尾注，删除 HTML 线。规范语义未改动。
v1.47（2026-08-27）：所有者三项指示——§5.2 可见性假设与"落最长链只经济激励、不强制"
定性 + 费用不进全序的取舍记录；§6.5 基础费分成（链 base fee 总和 × `φ_land` 收盘记入赢家，
偏差记附录 A-4）；§3.2 排班表代码化（`lookahead-model.py`，6 项断言）；全文去句中加粗约 670 处、
HTML 嵌套列表/§ 锚点链接/粗体减重修复。
v1.46（2026-08-26）：DeepSeek-on-v1.45 批次——模型 P9a 非空化（部署值独立声明、不等式互检），
并当即抓出 r44 的真实数值矛盾：`Δ_lag,final` 8-epoch 初值低于其自身公式（128+150 L1 slot），
重校为 **9 epoch ≈ 57.6 min**、`D_anchor_max` 估算 380→**≈420 L1 slot**；§5.6 澄清基线冻结 =
游标/状态（队列 append-only 按序号引用，勿用可变队列根做公共输入）+ 模型 P12；为当时的 HTML
生成器加 `--check` 漂移防护（该防护在 v1.48 随排版线迁移到 `build-pdf.py`）；P9b 显式时基。
21 项断言全过。
v1.45：可读性修订（五轮自审，零语义变更）——变更历史移入附录 D、新增导读/目录、全角标点规范、10 幅图嵌入正文、新增 HTML 版（该 HTML 线已于 v1.48 删除，由 LaTeX/PDF 取代）。
v1.44：**§12"实现前的门"两半均已交付** + DeepSeek-on-v1.43 批次修复。
后半（r44）:模型补 P8–P11（桥接预留饿死抵抗、anchor 几何/因果序、罚没按候选落地时点、兜底
资格快照）共 19 项断言全过 + 实现前复核文档（Solidity 存储/gas 分析与 Inbox 对接）;批次修复:
**拆 `Δ_lag,prov`/`Δ_lag,final` 阈值**（r42 换判定量未抬阈值,稳态 `lag_final ≈35–40 min` 高于
旧阈值 25.6 min → 兜底窗口在健康系统里永久开启,DeepSeek C1;`Δ_lag,final = Δ_lag,prov +
W_settle_max + 余量`,`D_anchor_max` 公式 lag 项同步升级 ≈250→380 L1 slot）、模型桥接预留
bug（C2→P8）、收盘先于接受规范化（W2）、术语清理（W1/W3）。门放行边界见复核文档"仍开放项"。
v1.43：§12"实现前的门"前半交付——结算窗口可执行参考模型 + 性质验证（附录 C）。
v1.42 基础：闭合独立审核终轮（第 5/5）的两项阻塞——最优链比较改为
候选自身四元组 `(lane,count,tip_slot,tip_hash)` 字典序（可证全序,修非传递环）;结算窗口补
**基线冻结 + 候选版本化 + 收盘提交**状态机（provisional 不改 canonical,收盘一笔提交赢家,
含伪代码）——并显式化 `T_include,max` 有界纳入假设、兜底会计快照至收盘、`D_anchor_max`
公式全文统一补 `Δ_lag`、拆分 lag_prov/lag_final、唯一化 `submission_slot`。独立审核五轮
完整闭环:方向 C 获确认,阻塞项全部落文,待实现前复核。v1.41 基础：初稿 + 三十余轮对抗评审修复 + **恢复子系统整体重设计
（方向 B）** + 规范性信任模型（所有者决定） + **结算窗口最终性（§5.6，所有者 option C，
2026-08-26）**：独立审核第 3/4 轮证明"无 DA 下机械裁决落地者该落什么"不可行（挑战层证不了
存在性,承诺层证不了块体可得性,修好即 episode 复杂度全量回流）,所有者据此**换根**——删除整套
挑战/承诺层,把最终性从"接受即最终"松弛为"**结算窗口 `W_settle` 内最重的已证明候选收盘即最终**":
更优的链自己带证明落进窗口直接赢,比较只在已落地已证明的候选间进行,块体可得性/投毒/存在性
证明问题全部结构性消失;落更差链从"可罚过错"变为"自败"。成本 = 最终性 +`W_settle`（≈20 分钟,
提款从 window-final 执行）,预确认秒级体验不变。连带:陈旧-anchor 死锁改参数几何解,罚没祖父化
用候选落地时点,`G_strike`/`H_force`/gas 前缀/恢复界等第 4 轮 bug 同修。（历史线：v1.39 挑战罚没层、v1.40 链头承诺层，均被独立审核第 3/4 轮证伪后由
option C 取代；更早的重锚 episode 由方向 B 两档父块规则取代——完整设计记录见规范文件顶部的
变更历史。）恢复子系统：**两档父块规则**（档 (i) 缺口 ≤ `G_max`,父块落地状态无关；档 (ii)
缺口无上限,父须 `L1-final` 落地头 + 签名时 `final_ref` 见证）,停摆（含数小时~数天）由普通
出块经落地头恢复排序。经设计者多轮自我对抗复核 + 独立 AI 深审四轮迭代。机制骨架完整,参数为
初始建议值。
规范性优先级：本目录以中文的 `slot-chain-spec.md` 为准；`slot-chain-spec.en.md` 与由它生成的
PDF 是同一文档的英文呈现，出入以中文版为准；`legacy-summary.md` 为非规范性背景。
