# Visual Understanding Environment (VUE)

VUE는 Tufts University에서 개발한 Java/Swing 기반의 개념 지도(concept map), 수업, 발표 도구입니다. 이 저장소의 주 목적은 오래된 VUE 2.x/3.x 계열 소스를 현재 Java 런타임, 특히 OpenJDK 25에서 다시 빌드하고 실행할 수 있게 만드는 것입니다.

## 현재 목표

현재 개발 환경의 Java는 다음 버전입니다.

```sh
openjdk version "25.0.2" 2026-01-20
OpenJDK Runtime Environment Homebrew (build 25.0.2)
OpenJDK 64-Bit Server VM Homebrew (build 25.0.2, mixed mode, sharing)
```

기존 VUE 코드는 Java 1.4-1.6 시절의 API, 빌드 설정, macOS 패키징 관례, Applet 지원, Java EE 번들 API에 의존합니다. 따라서 단순히 `java -jar`만으로는 JDK 25에서 동작하지 않습니다. 이 문서는 현재 소스 구조와 확인된 마이그레이션 과제를 정리한 첫 분석 문서입니다.

## 저장소 구조

| 경로 | 내용 |
| --- | --- |
| `VUE2/src` | VUE 본체 소스. Ant `build.xml`, Java/Swing 코드, 리소스, macOS 패키징 파일이 함께 있음 |
| `VUE2/lib` | VUE가 직접 포함하고 있는 서드파티 JAR 모음. 매우 오래된 Java EE, XML, RDF, Swing, OSID 관련 라이브러리가 포함됨 |
| `VUE2/test` | JUnit 및 OSID 관련 테스트/검증 코드 |
| `VUE2/jnilibs` | 네이티브 라이브러리 위치 |
| `VUE2/MacOS`, `VUE2/src/MacOS` | 구 macOS JavaApplicationStub/Info.plist 기반 패키징 리소스 |
| `VUE2/universalJavaApplicationStub-0.9.0` | Java 6-8 시대 macOS 앱 번들 호환용 스텁 |
| `VUE2/ZoteroFFExtension` | Zotero Firefox 확장 관련 코드 |
| `vue_releases` | 릴리스 산출물 생성 보조 스크립트 |
| `signing_code` | 코드 서명 관련 보조 스크립트 |

소스 규모는 `VUE2/src` 아래 Java 파일 약 906개입니다.

## 애플리케이션 진입점

메인 클래스는 다음과 같습니다.

```text
tufts.vue.VUE
```

Ant 빌드 파일도 실행 JAR의 `Main-Class`를 `tufts.vue.VUE`로 지정합니다. 주요 실행 타깃은 `VUE2/src/build.xml`의 `vue`, `vue-vanilla`, `jar`, `mac-dist`입니다.

## 기존 빌드 방식

프로젝트는 Maven/Gradle이 아니라 Ant 기반입니다.

```sh
cd VUE2/src
ant compile
ant jar
ant vue
```

기존 README는 Ant 1.6 이상을 전제로 합니다. 현재 로컬 환경에서는 `ant` 명령이 설치되어 있지 않아 Ant 빌드는 아직 실행하지 못했습니다.

```text
zsh:1: command not found: ant
```

## JDK 25에서 즉시 확인된 빌드 차단점

`VUE2/src/build.xml`은 다음 속성으로 컴파일 레벨을 고정합니다.

```xml
<property name="target.version" value="1.6"/>
```

JDK 25의 `javac`는 Java 6 소스/타깃 레벨을 더 이상 지원하지 않습니다. 최소한 Java 8 이상으로 올려야 컴파일 단계가 시작됩니다.

검증 결과:

```sh
javac -source 1.6 -target 1.6 Probe.java
```

결과:

```text
error: Source option 6 is no longer supported. Use 8 or later.
error: Target option 6 is no longer supported. Use 8 or later.
```

따라서 첫 번째 수정은 Ant의 `target.version`을 최소 `1.8`로 올리거나, 더 명시적으로 `--release 8`에 해당하는 빌드 구성을 도입하는 것입니다. 다만 이 변경만으로 JDK 25 실행까지 보장되지는 않습니다.

## JDK 25 포팅 위험 지점

### 1. Applet API

Applet 실행 모델은 현대 JDK/브라우저 환경에서 사실상 제거된 기능이므로, macOS 15용 데스크톱 `VUE.app` 목표에서는 제거 대상입니다. 포팅 2단계에서 Applet 본체, Applet 샘플 리소스, Applet JAR 빌드 타깃, Zotero Applet 브라우저 연동 코드를 제거했습니다.

대표 제거 대상:

- `VUE2/src/tufts/vue/VueApplet.java`
- `VUE2/applet-samplehtml`
- `VUE2/src/build.xml`의 `vue-applet`, `jar-core-applet`, `sign-applet-jars` 타깃

### 2. JDK 내부 패키지 사용

JDK 9 이후 모듈 시스템 때문에 `sun.*`, `com.sun.*`, `apple.*` 내부 패키지 접근은 강하게 제한됩니다. 현재 코드에는 다음 유형의 사용이 있습니다.

- `sun.java2d.*`
- `sun.awt.*`
- `sun.net.*`
- `com.sun.org.apache.xml.internal.*`
- `com.sun.swing.internal.*`
- `apple.awt.*`

대표 파일:

- `VUE2/src/tufts/vue/gui/DockWindow.java`
- `VUE2/src/tufts/vue/Images.java`
- `VUE2/src/tufts/vue/WriteSearchXMLData.java`
- `VUE2/src/tufts/vue/VueResources.java`
- `VUE2/src/tufts/vue/BrowseDataSource.java`

일부는 `--add-exports`/`--add-opens`로 임시 우회할 수 있지만, JDK 25에서 안정적으로 동작시키려면 공용 API로 대체하는 편이 맞습니다.

### 3. 구 macOS Java API

`maclib`에는 `com.apple.eawt.*`, 과거 `com.apple.cocoa.*` 기반 코드가 있습니다. 또한 `Info.plist`에는 Apple Java 1.5/1.6 시대 설정이 남아 있습니다.

대표 파일:

- `VUE2/src/maclib/MacOSX.java`
- `VUE2/src/maclib/MacOSX16Safe.java`
- `VUE2/src/maclib/MacTest.java`
- `VUE2/src/MacOS/Info.plist`

JDK 25에서는 `java.awt.Desktop`, `java.awt.desktop.*` 기반으로 재작성하는 것이 우선입니다.

### 4. Java EE/Jakarta 계열 API

JDK 11 이후 JDK에서 제거된 Java EE 모듈을 전제로 한 코드가 있습니다.

- `javax.activation.*`
- `javax.xml.rpc.*`
- `javax.xml.soap.*`
- JAXB 관련 JAR/API

이 저장소는 관련 JAR을 `VUE2/lib`에 직접 포함하고 있으므로 컴파일은 일부 통과할 수 있지만, 런타임 충돌과 모듈 경계 문제를 확인해야 합니다. 장기적으로는 Jakarta/대체 라이브러리 또는 기능 분리 전략이 필요합니다.

### 5. 오래된 서드파티 JAR

`VUE2/lib`에는 2000년대 중후반 라이브러리가 다수 포함되어 있습니다.

예:

- `castor-1.3-*`
- `log4j-1.2.12`
- `iText-2.1.4`
- `commons-httpclient-3.1-beta1`
- `xercesImpl-2.7.1`
- `xalan-2.4.1`
- `jaxrpc-*`, `saaj-*`, `activation-*`
- `apple-laf.jar`, `quaqua.jar`, `VAqua4.jar`

JDK 25 포팅에서는 빌드 성공 이후에도 classpath 순서, 중복 XML 파서, 보안 취약 라이브러리, 서명된 JAR 재패키징 문제가 발생할 가능성이 큽니다.

### 6. macOS 앱 패키징

현재 `mac-dist` 타깃은 `appbundler-1.0ea.jar`를 사용합니다. 오래된 `Info.plist`/JavaApplicationStub 방식과 현대 macOS 코드서명/노터라이즈 요구사항은 별도 정비가 필요합니다.

JDK 25 기준으로는 최종적으로 다음 중 하나로 옮기는 것이 현실적입니다.

- `jpackage`
- 최신 Gradle/Maven 플러그인 기반 앱 번들
- 기존 Ant 유지 + 별도 macOS 패키징 스크립트

## 권장 마이그레이션 순서

1. Ant 설치 후 현 상태 빌드를 재현합니다.
   ```sh
   cd VUE2/src
   ant -version
   ant clean compile
   ```

2. `target.version`을 `1.8` 이상으로 올려 JDK 25 `javac`가 실제 소스 오류를 보고하도록 만듭니다.

3. 데스크톱 앱 실행 경로를 우선 살립니다.
   - `tufts.vue.VUE` 중심으로 작업
   - Applet/Zotero Applet 경로는 제거하고 macOS 데스크톱 앱 경로만 유지

4. JDK 내부 API 사용을 공용 API로 치환합니다.
   - XML 직렬화: `Transformer` 또는 표준 DOM LS API
   - macOS 이벤트: `java.awt.desktop.*`
   - 이미지/GUI 내부 접근: Swing/AWT 공용 API 또는 기능 제거

5. Java EE 계열 의존성을 명시적으로 정리합니다.
   - 필요한 경우 기존 JAR을 임시 유지
   - 장기적으로 `javax.*` 제거/대체 또는 기능 모듈 분리

6. 실행 가능한 최소 JAR을 먼저 만듭니다.
   ```sh
   cd VUE2/src
   ant jar
   java -jar build/VUE.jar
   ```

7. 그 뒤 macOS 앱 번들을 복구합니다. Windows 인스톨러와 Zotero 확장은 별도 선택 과제로 둡니다.

## 임시 실행/디버깅 전략

초기에는 JDK 내부 API 접근 오류를 한 번에 제거하기 어렵습니다. 컴파일이 된 뒤 런타임에서 모듈 접근 오류가 발생하면 다음 옵션으로 원인을 좁힐 수 있습니다.

```sh
java \
  --add-exports java.desktop/sun.awt=ALL-UNNAMED \
  --add-exports java.desktop/sun.awt.image=ALL-UNNAMED \
  --add-exports java.desktop/sun.java2d=ALL-UNNAMED \
  --add-exports java.xml/com.sun.org.apache.xml.internal.serialize=ALL-UNNAMED \
  -jar VUE2/src/build/VUE.jar
```

이 옵션은 최종 해결책이 아니라 진단용입니다. 실제 목표는 이 옵션 없이 실행되는 상태입니다.

## 확인된 현재 상태

- JDK 25.0.2 설치 확인 완료
- `javac`가 `-source 1.6 -target 1.6`을 거부하는 것 확인 완료
- `ant` 미설치 확인 완료
- 메인 클래스가 `tufts.vue.VUE`인 것 확인 완료
- Ant 기반 단일 JAR 빌드 구조 확인 완료
- JDK 25 포팅 위험 API 목록 1차 확인 완료

## 다음 작업 후보

가장 작은 다음 변경은 다음과 같습니다.

1. 개발 환경에 Ant를 설치하거나 wrapper를 도입합니다.
2. `VUE2/src/build.xml`의 컴파일 레벨을 Java 8 이상으로 올립니다.
3. `ant clean compile`을 실행해 실제 컴파일 오류 목록을 확보합니다.
4. Applet/macOS 내부 API/Java EE API 오류를 우선순위대로 제거합니다.

이 저장소의 현재 상태에서는 문서화 다음 단계가 바로 “빌드 재현 가능 상태 만들기”입니다.
