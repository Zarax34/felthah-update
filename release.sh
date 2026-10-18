#!/usr/bin/env bash
# ============================================================================
# نشر إصدار جديد لتطبيق مراكز تحفيظ القرآن
# ============================================================================
# الاستخدام:
#   ./release.sh <مسار الحزمة> <versionCode> <versionName> ["ملاحظات"] [--mandatory]
#
# مثال:
#   ./release.sh ~/app-release.apk 2 1.0.1 "إصلاح الإشعارات"
#
# ما يفعله:
#   1. يحسب بصمة sha256 وحجم الحزمة
#   2. يرفعها أصلَ إصدار على GitHub (لا ملفاً في المستودع)
#   3. يحدّث manifest.json ويدفعه
#
# لماذا أصل إصدار لا ملف في المستودع؟ حزمة بـ ٧٠ ميغابايت في كل إصدار
# تُضخّم تاريخ git بلا رجعة. وأصول الإصدارات تدعم طلبات Range، وعليها
# يقوم استئناف التنزيل في التطبيق.
# ============================================================================
set -euo pipefail

APK="${1:?مسار الحزمة مطلوب}"
VERSION_CODE="${2:?versionCode مطلوب}"
VERSION_NAME="${3:?versionName مطلوب}"
NOTES="${4:-}"
MANDATORY=false
[[ "${5:-}" == "--mandatory" ]] && MANDATORY=true

[[ -f "$APK" ]] || { echo "✗ لا توجد حزمة في: $APK" >&2; exit 1; }
command -v gh >/dev/null || { echo "✗ gh غير مثبت — https://cli.github.com" >&2; exit 1; }

REPO="Zarax34/felthah-update"
TAG="v$VERSION_NAME"

echo "▸ حساب البصمة…"
SHA=$(sha256sum "$APK" | cut -d' ' -f1)
SIZE=$(stat -c%s "$APK" 2>/dev/null || stat -f%z "$APK")
echo "  sha256: $SHA"
echo "  الحجم:  $((SIZE / 1048576)) م.ب"

echo "▸ رفع الحزمة كأصل إصدار…"
# --clobber يسمح بإعادة الرفع لو فشل الدفع في محاولة سابقة
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$APK#app-release.apk" --repo "$REPO" --clobber
else
  gh release create "$TAG" "$APK#app-release.apk" \
    --repo "$REPO" --title "$VERSION_NAME" --notes "${NOTES:-إصدار $VERSION_NAME}"
fi

echo "▸ تحديث البيان…"
# البيان يُكتب بعد نجاح الرفع لا قبله: بيان يشير إلى حزمة غير موجودة
# يعني تطبيقات تحاول تنزيل رابط ميت
cat > manifest.json <<JSON
{
  "versionCode": $VERSION_CODE,
  "versionName": "$VERSION_NAME",
  "apkUrl": "https://github.com/$REPO/releases/download/$TAG/app-release.apk",
  "sha256": "$SHA",
  "sizeBytes": $SIZE,
  "mandatory": $MANDATORY,
  "releaseNotes": $(printf '%s' "${NOTES:-تحسينات وإصلاحات.}" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
}
JSON

git add manifest.json
git commit -m "release: $VERSION_NAME (versionCode $VERSION_CODE)"
git push

echo
echo "✓ نُشر $VERSION_NAME"
echo "  البيان: https://raw.githubusercontent.com/$REPO/main/manifest.json"
echo
echo "  تحقّق قبل أن تعتمد عليه:"
echo "    curl -s https://raw.githubusercontent.com/$REPO/main/manifest.json"
