#!/bin/bash

# ==============================================================================
# VUE macOS 빌드 & 시스템 캐시 정리 자동화 스크립트
# ==============================================================================

# 에러 발생 시 즉시 중단
set -e

echo "🧹 [1/4] macOS 시스템 캐시 및 Java App Caches 정리..."

# 1. macOS Launch Services 데이터베이스 캐시 초기화 및 재생성
# (개발용 VUE.app 빌드 경로 꼬임이나 캐싱된 구버전 연결 문제를 해결합니다)
if [ -f "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
    echo " -> Launch Services 캐시를 초기화하는 중..."
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user
    echo " -> [성공] Launch Services 캐시가 정리되었습니다."
else
    echo " -> [경고] lsregister 도구를 찾을 수 없어 Launch Services 정리를 건너뜁니다."
fi

# 2. Java AppBundler가 사용하는 macOS 유저 라이브러리 캐시 디렉토리 삭제
# (OS 캐싱으로 인한 구버전 JVM/클래스 참조 방지)
rm -rf ~/Library/Caches/VUE
rm -rf ~/Library/Caches/tufts.vue.VUE
echo " -> [성공] Java 애플리케이션 캐시 디렉토리가 삭제되었습니다."

echo "🧹 [2/4] 이전 빌드 잔재 정리 (ant clean)..."
# -f 플래그를 제거하여 Arguments(예: --workspace_id ...VUE)에 VUE 경로를 가진 IDE 프로세스가 동반 학살당하는 것을 방지합니다.
pkill -9 VUE || true
ant clean

echo "⚙️ [3/4] 소스코드 컴파일 (ant compile)..."
ant compile

echo "📦 [4/4] macOS 앱 번들 갱신 및 패키징 (ant mac-dist-jpackage)..."
ant mac-dist-jpackage

echo "✨ [완료] 빌드 및 캐시 클린업이 성공적으로 끝났습니다!"
echo "새로운 VUE.app 실행 경로: build/MacDistJPackage/VUE.app"

echo "🧹 [5/6] macOS 아이콘 캐시 갱신 및 Dock/Finder 리프레시..."
rm -rf ~/Library/Caches/com.apple.iconservices.store || true
# 시스템 부하 및 IDE 리로드 자극을 방지하기 위해 데스크톱 재부팅 명령은 주석 처리합니다.
# killall Dock || true
# killall Finder || true
sleep 1

echo "🚀 [6/6] VUE.app을 /Applications로 배포 및 시스템 전역 등록..."
# 프로세스명만으로 안전하게 선별 종료합니다.
pkill -9 VUE || true
# 기존 폴더 덮어쓰기 에러를 예방하기 위해 먼저 깔끔하게 삭제합니다.
rm -rf /Applications/VUE.app
cp -R build/MacDistJPackage/VUE.app /Applications/

# macOS TCC(보안 승인) 모듈이 앱의 Identity를 인지하여 권한 팝업을 정상 띄우도록 로컬 ad-hoc 서명을 적용합니다.
echo " -> 로컬 ad-hoc 코드 서명 중..."
codesign --force --deep -s - /Applications/VUE.app

# Gatekeeper 차단을 막기 위해 다운로드/격리 속성을 명시적으로 소거합니다.
echo " -> 격리 속성(Quarantine) 해제 중..."
xattr -r -d com.apple.quarantine /Applications/VUE.app || true

if [ -f "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister" ]; then
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Applications/VUE.app
fi

open /Applications/VUE.app || true

