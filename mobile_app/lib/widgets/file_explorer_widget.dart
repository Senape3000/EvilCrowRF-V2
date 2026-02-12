import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/file_item.dart';

class FileExplorerWidget extends StatelessWidget {
  final List<FileItem> files;
  final String currentPath;
  final Function(FileItem)? onFileTap;
  final Function(FileItem)? onDirectoryTap;
  final VoidCallback? onRefresh;
  final VoidCallback? onNavigateUp;
  final bool isLoading;
  final bool isChunking;
  final double chunkProgress;

  const FileExplorerWidget({
    super.key,
    required this.files,
    this.currentPath = '/',
    this.onFileTap,
    this.onDirectoryTap,
    this.onRefresh,
    this.onNavigateUp,
    this.isLoading = false,
    this.isChunking = false,
    this.chunkProgress = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.folder,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showFullPath(context),
                    child: Text(
                      AppLocalizations.of(context)!.sdCardPath(currentPath),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (currentPath != '/')
                  IconButton(
                    onPressed: isLoading ? null : onNavigateUp,
                    icon: const Icon(Icons.arrow_upward),
                    tooltip: AppLocalizations.of(context)!.goUp,
                  ),
                if (onRefresh != null)
                  IconButton(
                    onPressed: isLoading ? null : onRefresh,
                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    tooltip: AppLocalizations.of(context)!.refresh,
                  ),
              ],
            ),
          ),
          
          // Progress Bar for Chunking
          if (isChunking)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.download,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        AppLocalizations.of(context)!.downloadingFiles,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(chunkProgress * 100).toStringAsFixed(0)}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: chunkProgress,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          
          // File List
          Expanded(
            child: files.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.folder_open,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context)!.noFilesFound,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(context)!.connectToDeviceToSeeFiles,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: files.length,
                    itemBuilder: (context, index) {
                      final file = files[index];
                      return _buildFileItem(context, file);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, FileItem file) {
    return ListTile(
      leading: file.isDirectory
          ? SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                Icons.folder,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            )
          : Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getFileIcon(file.name),
                color: Theme.of(context).colorScheme.secondary,
                size: 20,
              ),
            ),
      title: Text(
        file.name,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: file.isFile && file.size > 0
          ? Text(
              file.sizeFormatted,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            )
          : null,
      trailing: file.isDirectory
          ? Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            )
          : null,
      onTap: () {
        if (file.isDirectory) {
          onDirectoryTap?.call(file);
        } else {
          onFileTap?.call(file);
        }
      },
    );
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    
    switch (extension) {
      case 'txt':
      case 'log':
        return Icons.description;
      case 'json':
        return Icons.code;
      case 'bin':
      case 'hex':
        return Icons.memory;
      case 'wav':
      case 'mp3':
        return Icons.audiotrack;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        return Icons.image;
      case 'zip':
      case 'rar':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }
  
  void _showFullPath(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.fullPath),
        content: SelectableText(
          currentPath,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.close),
          ),
        ],
      ),
    );
  }
}
