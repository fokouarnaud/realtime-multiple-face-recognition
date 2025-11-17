import 'package:flutter/material.dart';
import 'package:flutterface/config/routes.dart';
import 'package:flutterface/models/box_with_stats.dart';
import 'package:flutterface/services/database/face_database_service.dart';
import 'package:flutterface/services/snackbar/snackbar_service.dart';
import 'package:flutterface/ui/box_selection/widgets/box_card.dart';

class BoxSelectionPage extends StatelessWidget {
  const BoxSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Collections'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force a rebuild of the StreamBuilder
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: StreamBuilder<List<BoxWithStats>>(
          stream: FaceDatabaseService.instance.boxes.getBoxesWithStats(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _buildErrorState(snapshot.error.toString());
            }

            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final boxes = snapshot.data ?? [];

            return Column(
              children: [
                Expanded(
                  child: boxes.isEmpty
                      ? _buildEmptyState()
                      : _buildBoxList(context, boxes),
                ),
                _buildCreateButton(context),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading collections',
            style: TextStyle(
              fontSize: 18,
              color: Colors.red[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No collections yet',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoxList(BuildContext context, List<BoxWithStats> boxes) {
    return ListView.builder(
      itemCount: boxes.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) => BoxCard(
        box: boxes[index],
        onMenuAction: _handleMenuAction,
      ),
    );
  }


  Widget _buildCreateButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async => _showCreateBoxDialog(context),
          child: const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text('Create New Collection'),
          ),
        ),
      ),
    );
  }
  Future<void> _handleMenuAction(
      BuildContext context,
      String action,
      BoxWithStats box,
      ) async {
    switch (action) {
      case 'edit':
        await _showEditBoxDialog(context, box);
        break;
      case 'delete':
        await _showDeleteConfirmation(context, box);
        break;
    }
  }

  Future<void> _showEditBoxDialog(BuildContext context, BoxWithStats box) async {
    final nameController = TextEditingController(text: box.name);
    final descController = TextEditingController(text: box.description);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Collection'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (value) =>
                value?.trim().isEmpty == true ? 'Name is required' : null,
              ),
              TextFormField(
                controller: descController,
                decoration: const InputDecoration(labelText: 'Description'),
                validator: (value) =>
                value?.trim().isEmpty == true ? 'Description is required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await FaceDatabaseService.instance.boxes.updateBox(
          box.id,
          nameController.text.trim(),
          descController.text.trim(),
        );
        if (context.mounted) {
          SnackbarService.instance.showSuccess('Collection updated successfully');
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarService.instance.showError('Failed to update collection: $e');
        }
      }
    }

    nameController.dispose();
    descController.dispose();
  }

  Future<void> _showDeleteConfirmation(
      BuildContext context,
      BoxWithStats box,
      ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection'),
        content: Text(
          'Are you sure you want to delete "${box.name}"?\n\n'
              'This will also delete all ${box.faceCount} face records.\n'
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[700],
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true && context.mounted) {
      try {
        await FaceDatabaseService.instance.boxes.deleteBox(box.id);
        if (context.mounted) {
          SnackbarService.instance.showSuccess('Collection deleted successfully');
        }
      } catch (e) {
        if (context.mounted) {
          SnackbarService.instance.showError('Failed to delete collection: $e');
        }
      }
    }
  }



  Future<void> _showCreateBoxDialog(BuildContext context) async {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Collection'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    hintText: 'Enter collection name',
                    prefixIcon: const Icon(Icons.folder_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  textCapitalization: TextCapitalization.words,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: descController,
                  decoration: InputDecoration(
                    labelText: 'Description',
                    hintText: 'Enter collection description',
                    prefixIcon: const Icon(Icons.description_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a description';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );

    if (result == true) {
      try {
        if (!context.mounted) return;

        bool isLoading = true;
        // Show loading indicator using an overlay
        final overlay = OverlayEntry(
          builder: (context) => PopScope(
            canPop: false,
            child: Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ),
        );

        Overlay.of(context).insert(overlay);

        try {
          final box = await FaceDatabaseService.instance.boxes.createBox(
            nameController.text.trim(),
            descController.text.trim(),
          );

          if (!context.mounted) return;

          // Remove loading overlay
          overlay.remove();
          isLoading = false;

          // Navigate to home
          await Routes.navigateToHome(context, box.id, box.name);

        } catch (e) {
          if (!context.mounted) return;

          // Remove loading overlay if still showing
          if (isLoading) {
            overlay.remove();
          }

          // Show error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create collection: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }

      } finally {
        nameController.dispose();
        descController.dispose();
      }
    } else {
      nameController.dispose();
      descController.dispose();
    }
  }
}