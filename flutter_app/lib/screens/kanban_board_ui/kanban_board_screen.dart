import 'package:flutter/material.dart';
import 'package:appflowy_board/appflowy_board.dart';
import 'package:intl/intl.dart';
import 'package:faker/faker.dart' hide Color;
import 'package:uuid/uuid.dart';
import '../home_page.dart';

class KanbanColumnData {
  final String id;
  final String name;
  final Color color;

  KanbanColumnData({required this.id, required this.name, required this.color});
}

class User {
  final String id;
  final String name;
  final String image;

  User({required this.id, required this.name, required this.image});
}

class DragData {
  final KanbanTask task;
  final String sourceColumnId;
  DragData(this.task, this.sourceColumnId);
}

class KanbanTask extends AppFlowyGroupItem {
  @override
  final String id;
  final String name;
  final String? description;
  final DateTime startAt;
  final DateTime endAt;
  final String columnId;
  final User? owner;

  KanbanTask({
    required this.id,
    required this.name,
    this.description,
    required this.startAt,
    required this.endAt,
    required this.columnId,
    this.owner,
  });
}

class KanbanBoardScreen extends StatefulWidget {
  const KanbanBoardScreen({super.key});

  @override
  State<KanbanBoardScreen> createState() => _KanbanBoardScreenState();
}

class _KanbanBoardScreenState extends State<KanbanBoardScreen> {
  late AppFlowyBoardController controller;

  final List<KanbanColumnData> columns = [
    KanbanColumnData(id: 'col-1', name: "Planned", color: const Color(0xFF6B7280)),
    KanbanColumnData(id: 'col-2', name: "In Progress", color: const Color(0xFFF59E0B)),
    KanbanColumnData(id: 'col-3', name: "In Review", color: const Color(0xFF3B82F6)),
    KanbanColumnData(id: 'col-4', name: "Done", color: const Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    final faker = Faker();
    const uuid = Uuid();

    final users = List.generate(
      4,
      (index) => User(
        id: uuid.v4(),
        name: faker.person.name(),
        image: 'https://i.pravatar.cc/150?u=${uuid.v4()}',
      ),
    );

    final allFeatures = List.generate(20, (index) {
      final start = faker.date.dateTime(minYear: 2023, maxYear: 2024);
      final end = start.add(Duration(days: faker.randomGenerator.integer(60, min: 2)));
      return KanbanTask(
        id: uuid.v4(),
        name: faker.company.position(),
        description: faker.randomGenerator.boolean() ? faker.lorem.sentences(3).join(' ') : null,
        startAt: start,
        endAt: end,
        columnId: faker.randomGenerator.element(columns).id,
        owner: faker.randomGenerator.element(users),
      );
    });

    controller = AppFlowyBoardController(
      onMoveGroupItem: (groupId, fromIndex, toIndex) {},
      onMoveGroupItemToGroup: (fromGroupId, fromIndex, toGroupId, toIndex) {},
    );

    for (var col in columns) {
      final colTasks = allFeatures.where((t) => t.columnId == col.id).toList();
      controller.addGroup(AppFlowyGroupData(
        id: col.id,
        name: col.name,
        items: colTasks,
        customData: col,
      ));
    }
  }

  void _handleBackNavigation(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackNavigation(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF9FAFB),
        appBar: AppBar(
          title: const Text(
            'Kanban Board',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _handleBackNavigation(context),
          ),
          backgroundColor: Colors.white,
          elevation: 1,
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 600) {
              return _buildMobileGrid();
            }
            return _buildDesktopBoard(constraints);
          },
        ),
      ),
    );
  }

  // --- DESKTOP VIEW (AppFlowyBoard with drag-and-drop) ---

  Widget _buildDesktopBoard(BoxConstraints constraints) {
    final columnWidth = (constraints.maxWidth - 32) / 4.5; // Roughly fit 4 columns
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: AppFlowyBoard(
        controller: controller,
        cardBuilder: (context, group, groupItem) {
          return AppFlowyGroupCard(
            key: ValueKey(groupItem.id),
            decoration: const BoxDecoration(color: Colors.transparent),
            child: _buildTaskCard(groupItem as KanbanTask),
          );
        },
        headerBuilder: (context, columnData) {
          final colMeta = columnData.customData as KanbanColumnData;
          final currentItems = controller.getGroupController(columnData.id)?.items.length ?? 0;
          return _buildHeader(colMeta, currentItems);
        },
        footerBuilder: (context, columnData) => const SizedBox(height: 16),
        groupConstraints: BoxConstraints.tightFor(width: columnWidth > 280 ? columnWidth : 280),
        config: const AppFlowyBoardConfig(
          groupBackgroundColor: Colors.transparent,
          stretchGroupHeight: false,
        ),
      ),
    );
  }

  // --- MOBILE VIEW (2x2 Grid) ---

  Widget _buildMobileGrid() {
    final groups = controller.groupDatas;
    if (groups.length != 4) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildMobileColumn(groups[0])),
                const SizedBox(width: 8),
                Expanded(child: _buildMobileColumn(groups[1])),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildMobileColumn(groups[2])),
                const SizedBox(width: 8),
                Expanded(child: _buildMobileColumn(groups[3])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileColumn(AppFlowyGroupData group) {
    final colMeta = group.customData as KanbanColumnData;
    final groupController = controller.getGroupController(group.id);
    final currentItems = groupController?.items ?? [];

    return DragTarget<DragData>(
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data.sourceColumnId != group.id) {
          final oldGroup = controller.getGroupController(data.sourceColumnId);
          if (oldGroup != null) {
              controller.removeGroupItem(data.sourceColumnId, data.task.id);
              controller.addGroupItem(group.id, data.task);
              setState(() {});
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          decoration: BoxDecoration(
            color: candidateData.isNotEmpty ? Colors.blue.withOpacity(0.05) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: candidateData.isNotEmpty ? Colors.blue.shade300 : Colors.grey.shade200,
              width: candidateData.isNotEmpty ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              _buildHeader(colMeta, currentItems.length, true),
              Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: currentItems.length,
                  itemBuilder: (context, index) {
                    final task = currentItems[index] as KanbanTask;
                    return Draggable<DragData>(
                      data: DragData(task, group.id),
                      feedback: Material(
                        elevation: 8,
                        color: Colors.transparent,
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width / 2.2,
                          child: _buildTaskCard(task),
                        ),
                      ),
                      childWhenDragging: Opacity(
                        opacity: 0.3,
                        child: _buildTaskCard(task),
                      ),
                      child: _buildTaskCard(task),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- COMMON WIDGETS (Header & Card) ---

  Widget _buildHeader(KanbanColumnData col, [int count = 0, bool isMobile = false]) {
    return Container(
      margin: isMobile ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8, left: 8, right: 8, top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: col.color.withOpacity(0.08),
        borderRadius: isMobile 
            ? const BorderRadius.vertical(top: Radius.circular(11))
            : BorderRadius.circular(12),
        border: isMobile ? null : Border.all(color: col.color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: col.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              col.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: col.color.withOpacity(0.2)),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: col.color.withOpacity(0.8),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(KanbanTask task) {
    final shortDateFormatter = DateFormat('MMM d');
    final dateFormatter = DateFormat('MMM d, yyyy');

    return GestureDetector(
      onTap: () => _showTaskDetails(task),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (task.owner != null) ...[
                  const SizedBox(width: 8),
                  CircleAvatar(
                    radius: 10,
                    backgroundImage: NetworkImage(task.owner!.image),
                    backgroundColor: Colors.grey.shade200,
                    onBackgroundImageError: (_, __) {},
                    child: task.owner!.image.isEmpty
                        ? Text(
                            task.owner!.name.isNotEmpty ? task.owner!.name.substring(0, 1) : '?',
                            style: const TextStyle(fontSize: 10, color: Colors.black54),
                          )
                        : null,
                  ),
                ]
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${shortDateFormatter.format(task.startAt)} - ${dateFormatter.format(task.endAt)}',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTaskDetails(KanbanTask task) {
    final dateFormatter = DateFormat('MMM d, yyyy');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(color: Colors.blue.withOpacity(0.15), shape: BoxShape.circle),
                    child: const Icon(Icons.assignment, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dateFormatter.format(task.startAt)} - ${dateFormatter.format(task.endAt)}',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              if (task.description != null && task.description!.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Description',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    task.description!,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade800, height: 1.4),
                  ),
                ),
              ],
              if (task.owner != null) ...[
                const SizedBox(height: 24),
                const Text(
                  'Assignee',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundImage: NetworkImage(task.owner!.image),
                      backgroundColor: Colors.grey.shade200,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      task.owner!.name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class KanbanTaskFormWidget extends StatefulWidget {
  final KanbanColumnData category;
  final Function(String title, String description, DateTime startAt, DateTime endAt) onSubmit;
  final VoidCallback onCancel;

  const KanbanTaskFormWidget({
    super.key,
    required this.category,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<KanbanTaskFormWidget> createState() => _KanbanTaskFormWidgetState();
}

class _KanbanTaskFormWidgetState extends State<KanbanTaskFormWidget> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late DateTime _startAt;
  late DateTime _endAt;

  bool get _isValid => _titleController.text.trim().isNotEmpty && _endAt.isAfter(_startAt.subtract(const Duration(days: 1)));

  @override
  void initState() {
    super.initState();
    _startAt = DateTime.now();
    _endAt = _startAt.add(const Duration(days: 7));
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final initialDate = isStart ? _startAt : _endAt;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB), 
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startAt = picked;
          if (_endAt.isBefore(_startAt)) {
            _endAt = _startAt;
          }
        } else {
          _endAt = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('MMM d, yyyy');
    
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: widget.category.color.withOpacity(0.15), shape: BoxShape.circle),
                child: Icon(Icons.assignment, color: widget.category.color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Add to ${widget.category.name}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.close, color: Colors.grey.shade600, size: 20),
                  onPressed: widget.onCancel,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _titleController,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Task Title',
              labelStyle: TextStyle(color: Colors.grey.shade600),
              hintText: 'What needs to be done?',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descController,
            maxLines: 4,
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: TextStyle(color: Colors.grey.shade600),
              hintText: 'Add more details about this task...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              alignLabelWithHint: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.blue, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, true),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Start Date', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 8),
                            Text(dateFormatter.format(_startAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onTap: () => _selectDate(context, false),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('End Date', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.event, size: 16, color: Colors.grey.shade700),
                            const SizedBox(width: 8),
                            Text(dateFormatter.format(_endAt), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onCancel,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                    foregroundColor: Colors.grey.shade700,
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isValid
                      ? () => widget.onSubmit(_titleController.text.trim(), _descController.text.trim(), _startAt, _endAt)
                      : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: const Color(0xFF2563EB),
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 6,
                    shadowColor: const Color(0xFF2563EB).withOpacity(0.5),
                  ),
                  child: const Text('Add Task', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
