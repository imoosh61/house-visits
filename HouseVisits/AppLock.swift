import SwiftUI
import LocalAuthentication

/// قفل التطبيق: Face ID / Touch ID، وإذا ما نفع يطلب رمز الجوال.
/// إذا الجوال بدون رمز مرور، التطبيق يبقى مقفل (الأمان أولًا).
final class AppLock: ObservableObject {
    @Published var unlocked = false
    @Published var message: String?
    private var authenticating = false

    func authenticate() {
        guard !unlocked, !authenticating else { return }
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            message = "فعّل رمز المرور في إعدادات الآيفون لحماية التطبيق"
            return
        }
        authenticating = true
        context.evaluatePolicy(.deviceOwnerAuthentication,
                               localizedReason: "للدخول إلى بيانات البيوت") { ok, _ in
            DispatchQueue.main.async {
                self.authenticating = false
                if ok {
                    self.unlocked = true
                    self.message = nil
                } else {
                    self.message = "لم يتم التحقق من هويتك"
                }
            }
        }
    }

    func lock() {
        unlocked = false
        message = nil
    }
}

struct LockView: View {
    @EnvironmentObject var lock: AppLock

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 54))
                    .foregroundColor(.accentColor)
                Text("سجل الزيارات")
                    .font(.title2.bold())
                Text("التطبيق مقفل لحماية بيانات السكان")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let m = lock.message {
                    Text(m)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Button {
                    lock.authenticate()
                } label: {
                    Label("فتح التطبيق", systemImage: "faceid")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear { lock.authenticate() }
    }
}

/// يغطي المحتوى عند الانتقال بين التطبيقات حتى لا تظهر البيانات في المعاينة.
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
        }
    }
}
