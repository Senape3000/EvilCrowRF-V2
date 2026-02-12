import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_colors.dart';
import 'brute_screen.dart';
import 'record_screen.dart';

/// Sub-GHz wrapper screen — hosts Brute and Record as internal tabs
class SubGhzScreen extends StatefulWidget {
  const SubGhzScreen({super.key});

  @override
  State<SubGhzScreen> createState() => _SubGhzScreenState();
}

class _SubGhzScreenState extends State<SubGhzScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // Tab bar header
        Container(
          decoration: const BoxDecoration(
            color: AppColors.secondaryBackground,
            border: Border(
              bottom: BorderSide(color: AppColors.borderDefault, width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: _tabController.index == 0
                ? const Color(0xFFFF1744)
                : const Color(0xFF9C27B0),
            indicatorWeight: 2,
            labelColor: AppColors.primaryText,
            unselectedLabelColor: AppColors.secondaryText,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            tabs: [
              Tab(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radio_button_checked, size: 16,
                        color: _tabController.index == 0
                            ? const Color(0xFFFF1744)
                            : AppColors.secondaryText),
                    const SizedBox(width: 6),
                    Text(l10n.record,
                        style: TextStyle(
                          color: _tabController.index == 0
                              ? const Color(0xFFFF1744)
                              : AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
              Tab(
                height: 40,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_open, size: 16,
                        color: _tabController.index == 1
                            ? const Color(0xFF9C27B0)
                            : AppColors.secondaryText),
                    const SizedBox(width: 6),
                    Text(l10n.brute,
                        style: TextStyle(
                          color: _tabController.index == 1
                              ? const Color(0xFF9C27B0)
                              : AppColors.secondaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              RecordScreen(),
              BruteScreen(),
            ],
          ),
        ),
      ],
    );
  }
}
