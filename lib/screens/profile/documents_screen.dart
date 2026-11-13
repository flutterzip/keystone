import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/app_theme.dart';
import '../../config/app_timing.dart';
import '../../config/design_tokens.dart';
import '../../models/application.dart';
import '../../models/format.dart';
import '../../models/ids.dart';
import '../../providers/browse_providers.dart';
import '../../providers/core_providers.dart';
import '../../widgets/app_field.dart';
import '../../widgets/app_sheet.dart';
import '../../widgets/common.dart';
import '../../widgets/linger.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/removable.dart';

abstract final class DocumentKeys {
  static const add = Key('document-add');
  static const name = Key('document-name');
  static const save = Key('document-save');
  static Key row(String id) => Key('document-$id');
  static Key remove(String id) => Key('document-remove-$id');
  static Key kind(String k) => Key('document-kind-$k');
}

/// The papers that go with an application. Add one, rename it, remove it
/// with an undo. A new one is checked before it counts as verified.
class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  final _linger = Linger();
  final _removed = <String, Document>{};

  void _remove(Document d, List<Document> live) {
    final ids = [for (final x in live) x.id];
    final index = ids.indexOf(d.id);
    final documents = ref.read(documentsProvider.notifier);
    HapticFeedback.selectionClick();
    setState(() {
      _removed[d.id] = d;
      _linger.hold(d.id, ids);
    });
    documents.remove(d.id);
    showToast(
      context,
      '${d.name} removed',
      icon: Icons.delete_outline_rounded,
      onUndo: () => documents.save(d, at: index),
      onClosed: () {
        if (mounted) {
          setState(() {
            _linger.release(d.id);
            _removed.remove(d.id);
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final media = MediaQuery.of(context);
    final now = ref.watch(nowProvider);
    final live = ref.watch(documentsProvider).valueOrNull ?? const <Document>[];
    final byId = {..._removed, for (final d in live) d.id: d};
    final rows = _linger.rows([for (final d in live) d.id]);
    final have = {for (final d in live) d.kind};
    final missing = [
      for (final k in Document.kinds.take(2))
        if (!have.contains(k)) k,
    ];

    return SubPage(
      title: 'Documents',
      trailing: RoundIcon(
        key: DocumentKeys.add,
        icon: Icons.add_rounded,
        size: 22,
        label: 'Add a document',
        onTap: () => showDocumentSheet(context),
      ),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          Space.gutter,
          Space.lg,
          Space.gutter,
          media.padding.bottom + Sizes.tabBarReserve,
        ),
        children: [
          if (missing.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.lg),
              child: Notice(
                'Agents usually ask for: ${missing.join(' and ').toLowerCase()}.',
              ),
            ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.folder_outlined,
                title: 'No documents yet',
                message:
                    'Keep your ID and proof of income here and they go with every application.',
                action: 'Add a document',
                onAction: () => showDocumentSheet(context),
              ),
            ),
          for (final id in rows)
            if (byId[id] case final d?)
              Removable(
                key: ValueKey(id),
                gone: _linger.isGone(id),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Semantics(
                    button: true,
                    label:
                        '${d.name}, ${d.kind}, ${d.verified(now) ? 'verified' : 'being checked'}. Rename',
                    excludeSemantics: true,
                    child: InkWell(
                      key: DocumentKeys.row(id),
                      borderRadius: BorderRadius.circular(Radii.lg),
                      onTap: () => showDocumentSheet(context, editing: d),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(
                          Space.lg,
                          Space.md,
                          Space.xs,
                          Space.md,
                        ),
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(Radii.lg),
                          border: Border.all(color: p.line),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 50,
                              decoration: BoxDecoration(
                                color: p.field,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.description_outlined,
                                size: 21,
                                color: p.inkSoft,
                              ),
                            ),
                            const SizedBox(width: Space.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.title,
                                  ),
                                  Text(
                                    '${d.kind}, added ${inSentence(agoLabel(d.addedAt, now))}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.caption,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        d.verified(now)
                                            ? Icons.verified_outlined
                                            : Icons.hourglass_top_rounded,
                                        size: 14,
                                        color: d.verified(now)
                                            ? p.positive
                                            : p.accentInk,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        d.verified(now)
                                            ? 'Verified'
                                            : 'Being checked',
                                        style: context.caption.copyWith(
                                          color: d.verified(now)
                                              ? p.positive
                                              : p.accentInk,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            RoundIcon(
                              key: DocumentKeys.remove(id),
                              icon: Icons.delete_outline_rounded,
                              label: 'Remove ${d.name}',
                              onTap: _linger.isGone(id)
                                  ? null
                                  : () => _remove(d, live),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

/// Adds a document, or renames [editing].
Future<void> showDocumentSheet(BuildContext context, {Document? editing}) =>
    showAppSheet<void>(
      context,
      title: editing == null ? 'Add a document' : 'Rename document',
      builder: (_) => _DocumentForm(editing: editing),
    );

class _DocumentForm extends ConsumerStatefulWidget {
  const _DocumentForm({this.editing});

  final Document? editing;

  @override
  ConsumerState<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends ConsumerState<_DocumentForm> {
  late final _name = TextEditingController(text: widget.editing?.name);
  late String _kind = widget.editing?.kind ?? Document.kinds.first;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give it a name you will recognise');
      return;
    }
    setState(() => _busy = true);
    try {
      final editing = widget.editing;
      await AppTiming.atLeast(
        AppTiming.saveForm,
        ref
            .read(documentsProvider.notifier)
            .save(
              editing?.copyWith(name: name) ??
                  Document(
                    id: Ids.next('d'),
                    name: name,
                    kind: _kind,
                    addedAt: ref.read(clockProvider)(),
                  ),
            ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not save that. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.gutter,
        Space.sm,
        Space.gutter,
        Space.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.editing == null) ...[
            Text('KIND', style: context.label.copyWith(color: p.muted)),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in Document.kinds)
                  SelectChip(
                    key: DocumentKeys.kind(k),
                    label: k,
                    selected: k == _kind,
                    onTap: () => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: Space.xl),
          ],
          AppField(
            fieldKey: DocumentKeys.name,
            label: 'Name',
            controller: _name,
            hint: 'Passport, payslips, reference from a landlord',
            icon: Icons.description_outlined,
            error: _error,
            capitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: Space.xl),
          PrimaryButton(
            key: DocumentKeys.save,
            label: widget.editing == null ? 'Add document' : 'Save name',
            busy: _busy,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
