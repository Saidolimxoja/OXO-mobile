import 'package:flutter/material.dart';

import '../api/mobile_api.dart';
import '../api/models.dart';
import '../config.dart';
import '../i18n.dart';
import '../settings.dart';
import '../theme.dart';

String fmtUnits(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1).replaceAll('.', ',');

/// Работа в списке: вид, организация, время; раскрывается в детали с фото.
class JobTile extends StatefulWidget {
  final Job job;
  final VoidCallback? onDelete;
  const JobTile({super.key, required this.job, this.onDelete});

  @override
  State<JobTile> createState() => _JobTileState();
}

class _JobTileState extends State<JobTile> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final tone = Tone.of(context);
    final job = widget.job;
    final offline = job.kind == JobKind.offline;
    final color = offline ? Brand.indigo : Brand.mutedLight;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      onTap: () => setState(() => _open = !_open),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconChip(offline ? Icons.place_rounded : Icons.call_rounded, color: color, size: 38),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(job.orgName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      '${offline ? t('kindOffline') : t('kindOnline')} · '
                      '${job.workType?.name(AppSettings.instance.lang) ?? ''}',
                      style: TextStyle(fontSize: 12.5, color: tone.muted),
                    ),
                  ],
                ),
              ),
              Text('${hm(job.startedAt)}–${hm(job.finishedAt)}',
                  style: TextStyle(fontSize: 12.5, color: tone.muted, fontWeight: FontWeight.w600)),
            ],
          ),
          if (_open) ..._details(job, tone),
        ],
      ),
    );
  }

  List<Widget> _details(Job job, Tone tone) {
    final rows = <(String, String)>[
      (t('murojaatNo'), job.murojaatNo ?? t('directAppeal')),
      if (job.applicantName != null) (t('applicantName'), job.applicantName!),
      if (job.applicantPhone != null) (t('applicantPhone'), job.applicantPhone!),
      if (job.address != null) (t('place'), job.address!),
      (t('description'), job.description),
      (
        '${t('started')} – ${t('finished')}',
        '${hm(job.startedAt)} – ${hm(job.finishedAt)} · '
            '${job.finishedAt.difference(job.startedAt).inMinutes} ${t('minutes')}'
      ),
    ];

    return [
      const SizedBox(height: 12),
      for (final r in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(r.$1, style: TextStyle(fontSize: 13, color: tone.muted)),
              ),
              Expanded(
                child: Text(r.$2, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      if (job.photos.isNotEmpty) ...[
        const SizedBox(height: 6),
        SizedBox(
          height: 72,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: job.photos.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => _photo(context, job.photos[i]),
          ),
        ),
      ],
      if (widget.onDelete != null)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: widget.onDelete,
            icon: const Icon(Icons.delete_outline_rounded, color: Brand.red, size: 19),
            label: Text(t('deleteJob'), style: const TextStyle(color: Brand.red)),
          ),
        ),
    ];
  }

  Widget _photo(BuildContext context, JobPhoto photo) {
    final api = MobileApi.instance;
    final image = Image.network(
      api.photoUrl(photo),
      headers: api.photoHeaders,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );

    return GestureDetector(
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: InteractiveViewer(
            child: Image.network(api.photoUrl(photo), headers: api.photoHeaders),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(width: 72, height: 72, child: image),
      ),
    );
  }
}
