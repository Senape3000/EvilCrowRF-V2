import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/directory_tree_node.dart';

class DirectoryTreeWidget extends StatefulWidget {
  final List<DirectoryTreeNode> directories;
  final Function(String path) onDirectorySelected;
  final String? selectedPath;

  const DirectoryTreeWidget({
    super.key,
    required this.directories,
    required this.onDirectorySelected,
    this.selectedPath,
  });

  @override
  State<DirectoryTreeWidget> createState() => _DirectoryTreeWidgetState();
}

class _DirectoryTreeWidgetState extends State<DirectoryTreeWidget> {
  final Set<String> _expandedPaths = {};

  @override
  void initState() {
    super.initState();
    // Expand root by default
    _expandedPaths.add('/');
  }

  void _toggleExpanded(String path) {
    setState(() {
      if (_expandedPaths.contains(path)) {
        _expandedPaths.remove(path);
      } else {
        _expandedPaths.add(path);
      }
    });
  }

  String _buildFullPath(DirectoryTreeNode node, String? parentPath) {
    if (parentPath == null || parentPath == '/') {
      return node.path;
    }
    return '$parentPath${node.path}';
  }

  Widget _buildDirectoryNode(DirectoryTreeNode node, {String? parentPath, int level = 0}) {
    final fullPath = _buildFullPath(node, parentPath);
    final isExpanded = _expandedPaths.contains(fullPath);
    final isSelected = widget.selectedPath == fullPath;
    final hasChildren = node.directories.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => widget.onDirectorySelected(fullPath),
          child: Container(
            padding: EdgeInsets.only(
              left: level * 24.0 + 8.0,
              top: 10.0,
              bottom: 10.0,
              right: 8.0,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Row(
              children: [
                if (hasChildren)
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                    ),
                    onPressed: () => _toggleExpanded(fullPath),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  const SizedBox(width: 32),
                Icon(
                  Icons.folder,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    node.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isExpanded && hasChildren)
          ...node.directories.map((child) => _buildDirectoryNode(
                child,
                parentPath: fullPath,
                level: level + 1,
              )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      shrinkWrap: true,
      children: [
        // Root directory option (always shown)
        InkWell(
          onTap: () => widget.onDirectorySelected('/'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: widget.selectedPath == '/'
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4.0),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder_special,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.root,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: widget.selectedPath == '/' ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.directories.isNotEmpty) ...[
          const Divider(height: 1),
          // Directory tree
          ...widget.directories.map((dir) => _buildDirectoryNode(dir, parentPath: '/')),
        ] else ...[
          // Show message when no subdirectories
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              AppLocalizations.of(context)!.noSubdirectories,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

