import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/estimation.dart';
import '../services/database_service.dart';
import 'section1_screen.dart';
import 'section2_screen.dart';
import 'section3_screen.dart';
import 'section4_screen.dart';
import 'section5_screen.dart';
import 'section6_screen.dart';
import 'section7_screen.dart';

class EstimationFlow extends StatefulWidget {
  final Estimation? existing;
  const EstimationFlow({super.key, this.existing});

  @override
  State<EstimationFlow> createState() => _EstimationFlowState();
}

class _EstimationFlowState extends State<EstimationFlow> {
  late Estimation _e;
  int _step = 0;
  final _db = DatabaseService();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _e = widget.existing!;
    } else {
      final now = DateTime.now();
      final ref = 'EST-${now.year}-${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      _e = Estimation(
        id: const Uuid().v4(),
        reference: ref,
        createdAt: now,
        updatedAt: now,
        dateVisite: now,
        validiteJusquau: now.add(const Duration(days: 365)),
      );
    }
  }

  Future<void> _onChanged(Estimation updated) async {
    setState(() => _e = updated);
    await _db.saveEstimation(_e);
  }

  void _next() {
    if (_step < 6) setState(() => _step++);
  }

  void _prev() {
    if (_step > 0) setState(() => _step--);
    else Navigator.pop(context);
  }

  void _finish() {
    _db.saveEstimation(_e);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: _buildStep(),
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return Section1Screen(estimation: _e, onChanged: _onChanged, onNext: _next);
      case 1:
        return Section2Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev);
      case 2:
        return Section3Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev);
      case 3:
        return Section4Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev);
      case 4:
        return Section5Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev);
      case 5:
        return Section6Screen(estimation: _e, onChanged: _onChanged, onNext: _next, onPrev: _prev);
      case 6:
        return Section7Screen(estimation: _e, onChanged: _onChanged, onPrev: _prev, onFinish: _finish);
      default:
        return Section1Screen(estimation: _e, onChanged: _onChanged, onNext: _next);
    }
  }
}
