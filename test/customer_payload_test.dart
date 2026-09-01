import 'package:flutter_test/flutter_test.dart';
import 'package:solar_sales/features/customers/data/models/customer_model.dart';
import 'package:solar_sales/shared/utils/validators.dart';

void main() {
  group('Customer create payload — web panel parity', () {
    test('URP is sent as gst_number, not omitted', () {
      final customer = CustomerModel(
        id: '',
        name: 'Unregistered Customer',
        email: 'urp@example.com',
        phone: '9876543210',
        gstNumber: AppValidators.gstWriteValue('URP'),
      );

      expect(customer.toJson()['gst_number'], 'URP');
      expect(customer.toJson()['name'], 'Unregistered Customer');
      expect(customer.toJson()['email'], 'urp@example.com');
    });

    test('normal GSTIN is sent unchanged', () {
      final customer = CustomerModel(
        id: '',
        name: 'Registered Customer',
        gstNumber: AppValidators.gstWriteValue('22AAAAA0000A1Z5'),
      );

      expect(customer.toJson()['gst_number'], '22AAAAA0000A1Z5');
    });
  });
}
