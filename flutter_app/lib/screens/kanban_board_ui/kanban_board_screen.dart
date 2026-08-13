import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KanbanTask {
  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;

  KanbanTask({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
  });

  KanbanTask copyWith({String? status}) {
    return KanbanTask(
      id: id,
      title: title,
      description: description,
      status: status ?? this.status,
      priority: priority,
    );
  }
}

class KanbanBoardScreen extends StatefulWidget {
  const KanbanBoardScreen({super.key});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  bool _isAuthority = true;

  final List<String> _columns = [
    'Reported',
    'Under Investigation',
    'Action Taken',
    'Resolved'
  ];

  List<KanbanTask> _tasks = [
    KanbanTask(
      id: '1',
      title: 'Suspicious Activity in Library',
      description: 'A person was seen loitering around the library entrance.',
      status: 'Reported',
      priority: 'Low',
    ),
    KanbanTask(
      id: '2',
      title: 'Broken Streetlight near Gate B',
      description: 'The main streetlight is out, causing poor visibility.',
      status: 'Reported',
      priority: 'Medium',
    ),
    KanbanTask(
      id: '3',
      title: 'Lost Backpack at Cafeteria',
      description: 'A blue backpack was reported missing around 2 PM.',
      status: 'Under Investigation',
      priority: 'Low',
    ),
    KanbanTask(
      id: '4',
      title: 'Medical Emergency at Gym',
      description: 'Student slipped and fell in the gym, requires assistance.',
      status: 'Action Taken',
      priority: 'High',
    ),
    KanbanTask(
      id: '5',
      title: 'Fire Alarm Test Issue',
      description: 'Alarm did not go off in block C during the test.',
      status: 'Resolved',
      priority: 'Medium',
    ),
  ];

  void _updateTaskStatus(String taskId, String newStatus) {
    HapticFeedback.mediumImpact();
    setState(() {
      final index = _tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        _tasks[index] = _tasks[index].copyWith(status: newStatus);
      }
    });
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return const Color(0xFFEF4444); // Tailwind Red 500
      case 'Medium':
        return const Color(0xFFF59E0B); // Tailwind Amber 500
      case 'Low':
        return const Color(0xFF10B981); // Tailwind Emerald 500
      default:
        return const Color(0xFF6B7280); // Tailwind Gray 500
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Reported':
        return Icons.report_problem_rounded;
      case 'Under Investigation':
        return Icons.search_rounded;
      case 'Action Taken':
        return Icons.build_circle_rounded;
      case 'Resolved':
        return Icons.check_circle_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Reported':
        return const Color(0xFF3B82F6); // Blue
      case 'Under Investigation':
        return const Color(0xFF8B5CF6); // Purple
      case 'Action Taken':
        return const Color(0xFFF97316); // Orange
      case 'Resolved':
        return const Color(0xFF10B981); // Emerald
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Situations',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            Text(
              _isAuthority ? 'Editing Enabled' : 'Read-Only Mode',
              style: TextStyle(
                fontSize: 11,
                color: _isAuthority ? Colors.redAccent : Colors.grey.shade600,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1F2937),
        elevation: 0.5,
        actions: [
          Row(
            children: [
              Icon(
                _isAuthority ? Icons.admin_panel_settings : Icons.visibility,
                size: 16,
                color: _isAuthority ? const Color(0xFF3B82F6) : Colors.grey.shade500,
              ),
              const SizedBox(width: 4),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _isAuthority,
                  activeColor: const Color(0xFF3B82F6),
                  onChanged: (val) {
                    setState(() {
                      _isAuthority = val;
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;

            if (isMobile) {
              return Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _buildColumn(_columns[0], true)),
                          Expanded(child: _buildColumn(_columns[1], true)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _buildColumn(_columns[2], true)),
                          Expanded(child: _buildColumn(_columns[3], true)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            double columnWidth = 320;
            if (constraints.maxWidth > 1300) {
              columnWidth = (constraints.maxWidth - 32) / _columns.length;
            } else if (constraints.maxWidth > 800) {
              columnWidth = constraints.maxWidth / 3;
            } else {
              columnWidth = constraints.maxWidth / 2.2;
            }

            return ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16.0),
              itemCount: _columns.length,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: columnWidth,
                  child: _buildColumn(_columns[index], false),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildColumn(String status, bool isGrid) {
    if (!_isAuthority) {
      return _buildColumnContent(status, isGrid, false);
    }

    return DragTarget<String>(
      onWillAcceptWithDetails: (details) {
        // Find the task by ID and check if it's not already in this column
        try {
          final draggedTask = _tasks.firstWhere((t) => t.id == details.data);
          return draggedTask.status != status;
        } catch (e) {
          return false;
        }
      },
      onAcceptWithDetails: (details) {
        _updateTaskStatus(details.data, status);
      },
      builder: (context, candidateData, rejectedData) {
        return _buildColumnContent(status, isGrid, candidateData.isNotEmpty);
      },
    );
  }

  Widget _buildColumnContent(String status, bool isGrid, bool isHovering) {
    final columnTasks = _tasks.where((t) => t.status == status).toList();
    final statusColor = _getStatusColor(status);
    final statusIcon = _getStatusIcon(status);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: isGrid ? const EdgeInsets.all(4.0) : const EdgeInsets.only(right: 16.0),
      decoration: BoxDecoration(
        color: isHovering ? const Color(0xFF3B82F6).withOpacity(0.08) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isHovering ? const Color(0xFF3B82F6).withOpacity(0.5) : Colors.grey.shade200,
          width: isHovering ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Column Header
          Container(
            padding: EdgeInsets.all(isGrid ? 8.0 : 14.0),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.06),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: statusColor.withOpacity(0.12))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(statusIcon, color: statusColor, size: isGrid ? 14 : 18),
                      SizedBox(width: isGrid ? 4 : 8),
                      Expanded(
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: isGrid ? 11 : 14,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF374151),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isGrid ? 6 : 10, vertical: isGrid ? 2 : 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${columnTasks.length}',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: statusColor.withOpacity(0.9),
                      fontSize: isGrid ? 10 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Column Body
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.all(isGrid ? 6 : 12),
              itemCount: columnTasks.length,
              itemBuilder: (context, index) {
                final task = columnTasks[index];
                return _isAuthority ? _buildDraggableCard(task, isGrid) : _buildStaticCard(task, isGrid);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraggableCard(KanbanTask task, bool isGrid) {
    return LongPressDraggable<String>(
      key: ValueKey(task.id),
      data: task.id, // Passing just the ID to avoid state reference bugs
      dragAnchorStrategy: pointerDragAnchorStrategy,
      hapticFeedbackOnStart: true,
      feedback: Material(
        color: Colors.transparent,
        child: Material(
          elevation: 8,
          borderRadius: BorderRadius.circular(isGrid ? 8 : 12),
          child: SizedBox(
            width: isGrid ? 160 : 300,
            child: _TaskCardContent(
              task: task,
              priorityColor: _getPriorityColor(task.priority),
              isGrid: isGrid,
              isDragging: true,
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: _TaskCardContent(
          task: task,
          priorityColor: _getPriorityColor(task.priority),
          isGrid: isGrid,
        ),
      ),
      child: _TaskCardContent(
        task: task,
        priorityColor: _getPriorityColor(task.priority),
        isGrid: isGrid,
      ),
    );
  }

  Widget _buildStaticCard(KanbanTask task, bool isGrid) {
    return _TaskCardContent(
      key: ValueKey(task.id),
      task: task,
      priorityColor: _getPriorityColor(task.priority),
      isGrid: isGrid,
    );
  }
}

class _TaskCardContent extends StatelessWidget {
  final KanbanTask task;
  final Color priorityColor;
  final bool isGrid;
  final bool isDragging;

  const _TaskCardContent({
    super.key,
    required this.task,
    required this.priorityColor,
    this.isGrid = false,
    this.isDragging = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isGrid ? 6 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isGrid ? 8 : 12),
        border: Border.all(color: Colors.grey.shade200, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDragging ? 0.12 : 0.03),
            blurRadius: isDragging ? 12 : 4,
            offset: isDragging ? const Offset(0, 8) : const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isGrid ? 10.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isGrid ? 11 : 14,
                      color: const Color(0xFF1F2937),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              task.description,
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: isGrid ? 10 : 12,
                height: 1.3,
              ),
              maxLines: isGrid ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: isGrid ? 8 : 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isGrid ? 6 : 8, vertical: isGrid ? 3 : 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: priorityColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flag_rounded, size: isGrid ? 10 : 12, color: priorityColor),
                      SizedBox(width: isGrid ? 2 : 4),
                      Text(
                        task.priority,
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: isGrid ? 9 : 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '#${task.id}',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: isGrid ? 10 : 12,
                    fontWeight: FontWeight.w600,
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
