import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:wellspring/services/resource_service.dart';
import 'package:wellspring/services/resource_suggestion_service.dart';
import 'package:wellspring/theme.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/foundation.dart';

class RecommendResourceSheet extends StatefulWidget {
  const RecommendResourceSheet({super.key});

  @override
  State<RecommendResourceSheet> createState() => _RecommendResourceSheetState();
}

class _RecommendResourceSheetState extends State<RecommendResourceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _typeItems = const ['therapist', 'center', 'hospital', 'service', 'pharmacy'];
  String _type = 'service';
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _postal = TextEditingController();
  final _country = TextEditingController();
  final _phone = TextEditingController();
  final _website = TextEditingController();
  final _email = TextEditingController();
  final _desc = TextEditingController();
  final _specialties = TextEditingController(); // comma-separated

  double? _lat;
  double? _lng;
  String? _geoLabel;
  bool _submitting = false;

  final _resourceService = ResourceService();
  final _suggestionService = ResourceSuggestionService();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _city.dispose();
    _state.dispose();
    _postal.dispose();
    _country.dispose();
    _phone.dispose();
    _website.dispose();
    _email.dispose();
    _desc.dispose();
    _specialties.dispose();
    super.dispose();
  }

  Future<void> _geocode() async {
    final q = [
      _address.text.trim(),
      _city.text.trim(),
      _state.text.trim(),
      _postal.text.trim(),
      _country.text.trim(),
    ].where((s) => s.isNotEmpty).join(', ');
    if (q.isEmpty) return;
    final res = await _resourceService.geocodeAddress(q);
    if (res == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not geocode that address')));
      }
      return;
    }
    setState(() {
      _lat = (res['lat'] as num).toDouble();
      _lng = (res['lng'] as num).toDouble();
      _geoLabel = (res['label'] as String?) ?? q;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final specs = _specialties.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    final payload = <String, dynamic>{
      'name': _name.text.trim(),
      'type': _type,
      'address': _address.text.trim(),
      if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
      if (_state.text.trim().isNotEmpty) 'state': _state.text.trim(),
      if (_postal.text.trim().isNotEmpty) 'postalCode': _postal.text.trim(),
      if (_country.text.trim().isNotEmpty) 'country': _country.text.trim(),
      if (_lat != null) 'lat': _lat,
      if (_lng != null) 'lng': _lng,
      if (_phone.text.trim().isNotEmpty) 'phone': _phone.text.trim(),
      if (_website.text.trim().isNotEmpty) 'website': _website.text.trim(),
      if (_email.text.trim().isNotEmpty) 'contactEmail': _email.text.trim(),
      if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
      if (specs.isNotEmpty) 'specialties': specs,
    };
    try {
      final u = auth.FirebaseAuth.instance.currentUser;
      debugPrint('RecommendResourceSheet: currentUser=${u?.uid ?? 'null'} email=${u?.email ?? 'null'}');
      // Extra diagnostics to pinpoint Firestore rules failures
      try {
        // Lazy import to avoid analyzer complaining when firebase_auth isn't configured for some envs
        // ignore: avoid_dynamic_calls
        final _ = null;
      } catch (_) {}
      // Print a concise payload snapshot (no PII except email if provided)
      debugPrint('RecommendResourceSheet: submitting suggestion: '
          'name="${_name.text.trim()}" type="$_type" city="${_city.text.trim()}" state="${_state.text.trim()}" lat=${_lat?.toStringAsFixed(5)} lng=${_lng?.toStringAsFixed(5)}');
      await _suggestionService.submitSuggestion(payload);
      if (mounted) {
        // Clear inputs to avoid stale content if reopened quickly
        _name.clear();
        _address.clear();
        _city.clear();
        _state.clear();
        _postal.clear();
        _country.clear();
        _phone.clear();
        _website.clear();
        _email.clear();
        _desc.clear();
        _specialties.clear();
        _lat = null; _lng = null; _geoLabel = null;

        context.pop(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Suggestion submitted — thank you!')));
      }
    } catch (e) {
      debugPrint('RecommendResourceSheet: submit failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.add_business, color: cs.primary),
                    SizedBox(width: AppSpacing.sm),
                    Text('Recommend a resource', style: context.textStyles.titleLarge?.semiBold),
                    const Spacer(),
                    IconButton(onPressed: () => context.pop(), icon: const Icon(Icons.close)),
                  ],
                ),
                SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Resource name *', prefixIcon: Icon(Icons.business_outlined)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _type,
                  items: _typeItems.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => _type = v ?? 'service'),
                  decoration: const InputDecoration(labelText: 'Type', prefixIcon: Icon(Icons.category_outlined)),
                ),
                SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: 'Address line *', prefixIcon: Icon(Icons.place_outlined)),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(child: TextFormField(controller: _city, decoration: const InputDecoration(labelText: 'City'))),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: TextFormField(controller: _state, decoration: const InputDecoration(labelText: 'State/Province'))),
                ]),
                SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(child: TextFormField(controller: _postal, decoration: const InputDecoration(labelText: 'Postal code'))),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(child: TextFormField(controller: _country, decoration: const InputDecoration(labelText: 'Country'))),
                ]),
                SizedBox(height: AppSpacing.xs),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _geocode,
                      icon: const Icon(Icons.map_outlined),
                      label: Text(_geoLabel == null ? 'Find coordinates' : 'Found: $_geoLabel'),
                    ),
                  ),
                ]),
                SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(child: TextFormField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone', prefixIcon: Icon(Icons.call_outlined))))
                ]),
                SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(child: TextFormField(controller: _website, decoration: const InputDecoration(labelText: 'Website', prefixIcon: Icon(Icons.link_outlined))))
                ]),
                SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(child: TextFormField(controller: _email, decoration: const InputDecoration(labelText: 'Contact email (optional)', prefixIcon: Icon(Icons.alternate_email))))
                ]),
                SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _specialties,
                  decoration: const InputDecoration(labelText: 'Specialties (comma-separated)', prefixIcon: Icon(Icons.sell_outlined)),
                ),
                SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _desc,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Notes for us (optional)', prefixIcon: Icon(Icons.notes_outlined)),
                ),
                SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: const Icon(Icons.send, color: Colors.white),
                    label: Text(_submitting ? 'Submitting…' : 'Submit suggestion'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
