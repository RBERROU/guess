import 'dart:math' as math;
import 'dart:typed_data';

/// FFT radix-2 minimale, sans dépendance.
/// On n'a besoin que du spectre d'amplitude sur des fenêtres courtes.
class Fft {
  /// Amplitudes du spectre pour une fenêtre de taille puissance de 2.
  /// Renvoie n/2 valeurs (le reste est symétrique).
  static Float64List magnitudes(Float64List input) {
    final n = input.length;
    assert(n > 0 && (n & (n - 1)) == 0, 'la taille doit être une puissance de 2');

    final re = Float64List.fromList(input);
    final im = Float64List(n);

    // Permutation binaire inverse
    for (int i = 1, j = 0; i < n; i++) {
      int bit = n >> 1;
      for (; j & bit != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tr = re[i]; re[i] = re[j]; re[j] = tr;
        final ti = im[i]; im[i] = im[j]; im[j] = ti;
      }
    }

    for (int len = 2; len <= n; len <<= 1) {
      final ang = -2 * math.pi / len;
      final wr = math.cos(ang), wi = math.sin(ang);
      for (int i = 0; i < n; i += len) {
        double cr = 1, ci = 0;
        for (int k = 0; k < len ~/ 2; k++) {
          final ur = re[i + k], ui = im[i + k];
          final vr = re[i + k + len ~/ 2] * cr - im[i + k + len ~/ 2] * ci;
          final vi = re[i + k + len ~/ 2] * ci + im[i + k + len ~/ 2] * cr;
          re[i + k] = ur + vr;
          im[i + k] = ui + vi;
          re[i + k + len ~/ 2] = ur - vr;
          im[i + k + len ~/ 2] = ui - vi;
          final ncr = cr * wr - ci * wi;
          ci = cr * wi + ci * wr;
          cr = ncr;
        }
      }
    }

    final half = n ~/ 2;
    final out = Float64List(half);
    for (int i = 0; i < half; i++) {
      out[i] = math.sqrt(re[i] * re[i] + im[i] * im[i]);
    }
    return out;
  }

  /// Fenêtre de Hann, pour éviter les fuites spectrales aux bords.
  static Float64List hann(int n) {
    final w = Float64List(n);
    for (int i = 0; i < n; i++) {
      w[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
    }
    return w;
  }
}
