import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../shared/models/goal_model.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../data/repositories/goal_repository.dart';
import 'goal_detail_page.dart';
import 'add_goal_page.dart';

class GoalListPage extends StatefulWidget {
  const GoalListPage({super.key});

  @override
  State<GoalListPage> createState() => _GoalListPageState();
}

class _GoalListPageState extends State<GoalListPage>
    with SingleTickerProviderStateMixin {
  // ──────────────────────────── สีหลัก ────────────────────────────
  static const brown = Color(0xFF5A3A28);
  static const cream = Color(0xFFF8F4EE);
  static const green = Color(0xFF5E8065);
  
  late TabController _tabController;
  final GoalRepository _goalRepository = GoalRepository();
  final List<GoalModel> _goals = [];
  bool _loading = true;
  int? _loadedUserId;
  int _dataRevision = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userProvider = context.watch<UserProvider>();
    final userId = userProvider.user?.id;
    if (userId != _loadedUserId || userProvider.dataRevision != _dataRevision) {
      _loadedUserId = userId;
      _dataRevision = userProvider.dataRevision;
      _loading = true;
      _loadGoals();
    }
  }

  Future<void> _loadGoals() async {
    final userId = context.read<UserProvider>().user?.id;
    if (userId == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final goals = await _goalRepository.getGoals(userId);
      if (!mounted) return;
      setState(() {
        _goals
          ..clear()
          ..addAll(goals);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('โหลดเป้าหมายไม่สำเร็จ: $error')),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<GoalModel> get _activeGoals =>
      _goals.where((g) => !g.isCompleted).toList();

  List<GoalModel> get _completedGoals =>
      _goals.where((g) => g.isCompleted).toList();

  double get _totalRemaining {
    return _activeGoals.fold(0.0, (sum, g) => sum + g.remainingAmount);
  }

  String _formatAmount(double amount) {
    return amount.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
  }

  void _openAddGoal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddGoalPage(
          onAdd: (GoalModel newGoal) async {
            final userProvider = context.read<UserProvider>();
            final userId = userProvider.user?.id;
            if (userId == null) throw StateError('กรุณาเข้าสู่ระบบอีกครั้ง');
            final savedGoal = await _goalRepository.createGoal(userId, newGoal);
            if (!mounted) return;
            setState(() {
              _goals.insert(0, savedGoal);
            });
            userProvider.notifyDataChanged();
          },
        ),
      ),
    );
  }

  void _openGoalDetail(GoalModel goal) {
    final index = _goals.indexOf(goal);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GoalDetailPage(
          goal: goal,
          onGoalUpdated: (updatedGoal) {
            if (index >= 0) {
              setState(() {
                _goals[index] = updatedGoal;
              });
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        backgroundColor: cream,
        foregroundColor: Colors.black,
        title: const Text(
          'เป้าหมายทั้งหมด',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.black),
            onPressed: _openAddGoal,
          )
        ],
      ),
      body: Column(
        children: [
          // ── Tabs ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEBE6E0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: brown,
                unselectedLabelColor: const Color(0xFF9A928B),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                tabs: [
                  Tab(text: 'กำลังออม ${_activeGoals.length}'),
                  Tab(text: 'บรรลุแล้ว ${_completedGoals.length}'),
                ],
              ),
            ),
          ),

          // ── Content ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGoalList(_activeGoals, isActive: true),
                _buildGoalList(_completedGoals, isActive: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalList(List<GoalModel> list, {required bool isActive}) {
    if (list.isEmpty) {
      return const Center(
        child: Text('ไม่มีเป้าหมายในหมวดหมู่นี้'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: list.length + (isActive ? 1 : 1),
      itemBuilder: (context, index) {
        if (index == 0) {
          // Header summary
          if (isActive) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'กำลังออม (${list.length})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF77716C),
                    ),
                  ),
                  Text(
                    'รวมเหลือ ฿ ${_formatAmount(_totalRemaining)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A928B),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'บรรลุแล้ว (${list.length})',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF77716C),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('🎉', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                  const Text(
                    'สำเร็จ 100%',
                    style: TextStyle(
                      fontSize: 12,
                      color: green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            );
          }
        }

        final goal = list[index - 1];
        return _buildGoalCard(goal);
      },
    );
  }

  Widget _buildGoalCard(GoalModel goal) {
    final isCompleted = goal.isCompleted;
    final progress = goal.progressPercentage;
    final int pct = (progress * 100).toInt();

    final Color primaryColor = isCompleted ? green : const Color(0xFFC97864);
    
    // Map codePoint to IconData
    final iconWidget = Icon(
      // ignore: non_const_call_to_factory_body, non_const_argument_for_const_parameter
      IconData(goal.iconCodePoint, fontFamily: 'MaterialIcons'),
      color: Colors.white,
      size: 20,
    );

    return GestureDetector(
      onTap: () => _openGoalDetail(goal),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: iconWidget,
                ),
                const SizedBox(width: 12),
                
                // Title
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        goal.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF38312C),
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'สำเร็จแล้ว',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: green,
                            ),
                          ),
                        ),
                      ]
                    ],
                  ),
                ),

                // Percentage
                Text(
                  '$pct%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF38312C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFEBE6E0),
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
            const SizedBox(height: 12),

            // Amounts
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '฿ ${_formatAmount(goal.currentAmount)} / ฿ ${_formatAmount(goal.targetAmount)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF77716C),
                  ),
                ),
                if (isCompleted)
                  const Row(
                    children: [
                      Icon(Icons.check_rounded, size: 14, color: green),
                      SizedBox(width: 4),
                      Text(
                        'ออมครบแล้ว',
                        style: TextStyle(
                          fontSize: 12,
                          color: green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'เหลืออีก ฿ ${_formatAmount(goal.remainingAmount)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF77716C),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
