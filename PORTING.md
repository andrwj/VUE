# VUE JDK 25 Porting Log

이 문서는 VUE를 OpenJDK 25에서 빌드하고 실행하기 위한 포팅 과정의 설정 변경, 문제점, 해결책, 검증 결과를 기록한다.

## 환경

- 날짜: 2026-05-12
- Java: OpenJDK 25.0.2
- Ant: Apache Ant 1.10.17
- 작업 디렉터리: `/Users/andrwj/Develops/github/VUE`
- 주요 빌드 파일: `VUE2/src/build.xml`

## 1단계: Ant 컴파일 레벨을 Java 8로 상향

### 배경

기존 빌드 파일은 Java 6 컴파일 레벨을 사용한다.

```xml
<property name="target.version" value="1.6"/>
```

JDK 25의 `javac`는 `-source 6`, `-target 1.6`을 더 이상 지원하지 않기 때문에 Ant 자체가 정상이어도 실제 소스 컴파일 전에 빌드가 중단된다.

### 문제

`cd VUE2/src && ant clean compile` 실행 시 다음 오류로 실패했다.

```text
error: Source option 6 is no longer supported. Use 8 or later.
error: Target option 6 is no longer supported. Use 8 or later.
```

실패 위치는 `VUE2/src/build.xml`의 `<javac>` 태스크이며, 모든 `<javac>` 태스크가 공통 속성 `target.version`을 참조한다.

### 해결책

`VUE2/src/build.xml`의 공통 컴파일 레벨을 Java 8로 변경했다.

```xml
<property name="target.version" value="1.8"/>
```

Java 8은 JDK 25 `javac`가 지원하는 가장 낮은 실용적 소스/타깃 레벨이며, 기존 Java 6 코드와의 문법 호환성도 가장 보수적으로 유지한다.

### 검증

이 설정 변경 후 `ant clean compile`을 다시 실행해 Java 6 옵션 차단이 해소되는지 확인한다. 새로 드러나는 컴파일 오류는 다음 단계의 입력으로 기록하고, 1단계에서는 수정하지 않는다.

검증 명령:

```sh
cd VUE2/src
ant clean compile
```

결과:

- Java 6 컴파일 옵션 오류는 해소되었다.
- 빌드는 실제 Java 소스 컴파일 단계까지 진행되었다.
- 다음 컴파일 차단점이 드러났다.

새로 확인된 오류:

```text
VUE2/src/tufts/vue/Actions.java:1332: error: cannot find symbol
  symbol:   method getWindow(JApplet)
  location: class JSObject

VUE2/src/tufts/vue/Actions.java:1352: error: cannot find symbol
  symbol:   method getWindow(JApplet)
  location: class JSObject

VUE2/src/tufts/vue/Actions.java:1360: error: cannot find symbol
  symbol:   method getWindow(JApplet)
  location: class JSObject

VUE2/src/tufts/vue/ds/DataTree.java:1953: error: incompatible types:
  Vector<TreeNode> cannot be converted to Vector<DataNode>
```

주요 경고:

- `java.applet.AppletContext`, `javax.swing.JApplet`, `netscape.javascript.JSObject`는 제거 예정 API다.
- `sun.net.*`, `sun.java2d.*`, `sun.awt.image.*`, `com.sun.org.apache.xerces.internal.*` 같은 내부 JDK API 사용이 확인되었다.
- Java 8 소스/타깃 옵션 자체도 JDK 25에서는 obsolete 경고를 낸다. 현재는 포팅 출발점으로 유지한다.

### 1단계 결론

1단계 목표인 “JDK 25가 거부하는 Java 6 컴파일 설정 제거”는 완료되었다. 다음 단계는 `Actions.java`의 Zotero/Applet 브라우저 연동 경로를 데스크톱 빌드에서 분리하거나 현대 API에 맞게 비활성화하고, `DataTree.java`의 제네릭 타입 오류를 수정하는 것이다.

## 2단계: Applet 코드 제거 및 데스크톱 컴파일 복구

### 배경

최종 목표는 macOS 15에서 실행 가능한 데스크톱 `VUE.app`이다. Applet 실행 모델, 브라우저 JavaScript 연동, Applet용 JAR/샘플 배포물은 현대 macOS 데스크톱 앱 목표와 맞지 않으므로 제거 대상으로 결정했다.

### 문제

1단계 후 `ant clean compile`에서 다음 오류가 발생했다.

```text
VUE2/src/tufts/vue/Actions.java:1332: error: cannot find symbol
  symbol:   method getWindow(JApplet)
  location: class JSObject

VUE2/src/tufts/vue/Actions.java:1352: error: cannot find symbol
  symbol:   method getWindow(JApplet)
  location: class JSObject

VUE2/src/tufts/vue/Actions.java:1360: error: cannot find symbol
  symbol:   method getWindow(JApplet)
  location: class JSObject

VUE2/src/tufts/vue/ds/DataTree.java:1953: error: incompatible types:
  Vector<TreeNode> cannot be converted to Vector<DataNode>
```

`Actions.java`의 오류는 Zotero Applet 액션이 `netscape.javascript.JSObject.getWindow(JApplet)`에 의존하기 때문에 발생했다. 이 경로는 데스크톱 `VUE.app`에 필요하지 않다.

### 해결책

Applet 관련 코드를 제거했다.

- `VUE2/src/tufts/vue/VueApplet.java` 삭제
- `VUE2/applet-samplehtml` 하위 Applet 샘플 파일 삭제
- `VUE2/src/build.xml`에서 Applet 산출물 속성 및 타깃 제거
  - `vueapplet.jar`
  - `vueapplet-pack.jar`
  - `jar-core-applet`
  - `run-jar-core-applet`
  - `sign-applet-jars`
  - `vue-applet`
  - 릴리스 ZIP/checksum의 `VUEApplet.zip` 처리
- `Actions.java`에서 Zotero Applet 브라우저 연동 액션 제거
  - `SaveCopyToZotero`
  - `AddResourceToZotero`
- `VUE.java`, `MapViewer.java`, `VueMenuBar.java`, `VueUtil.java`에서 직접적인 `VueApplet`, `AppletContext`, `JApplet`, `netscape.javascript` 참조 제거
- 데스크톱 전용 빌드를 위해 `VUE.isApplet()`은 항상 `false`를 반환하도록 정리
- `DataTree.java`의 `DefaultMutableTreeNode.children` 제네릭 타입 오류는 기존 런타임 구조를 유지하는 unchecked cast로 보정

Applet 제거 후 다음 컴파일 차단점이 추가로 드러났다.

```text
VUE2/src/tufts/vue/VueAimPanel.java:49: error:
  package sun.net.ProgressSource does not exist

VUE2/src/edu/tufts/vue/collab/im/VUEAim.java:55: error:
  package sun.net.ProgressSource does not exist

VUE2/src/edu/tufts/vue/collab/im/VUEAim.java:425: error:
  package State does not exist

VUE2/src/tufts/vue/WriteSearchXMLData.java:158: error:
  no suitable constructor found for OutputFormat(Document)
```

추가 해결:

- `sun.net.ProgressSource.State` 내부 API import 제거
- AIM 연결 상태 비교를 `"CONNECTED".equals(bosConn.getState().toString())`로 변경
- `WriteSearchXMLData`의 `com.sun.org.apache.xml.internal.serialize.*` 사용을 표준 `javax.xml.transform.Transformer` 기반 출력으로 변경

### 검증

검증 명령:

```sh
cd VUE2/src
ant clean compile
```

결과:

```text
BUILD SUCCESSFUL
Total time: 3 seconds
```

2단계 완료 시점에서 JDK 25 + Ant 1.10.17 환경의 `ant clean compile`은 성공한다.

### 남은 경고 및 리스크

컴파일은 성공했지만 다음 경고는 남아 있다.

- `source/target 8`은 JDK 25에서 obsolete 경고를 낸다.
- `sun.net.www.protocol.file.FileURLConnection`, `sun.java2d.*`, `sun.awt.image.ToolkitImage` 등 내부 JDK API 사용이 남아 있다.
- `Thread.stop()`, `finalize()`, `AccessControlException` 등 제거 예정 API 사용이 남아 있다.

다음 단계는 `ant jar`로 실행 JAR 생성까지 진행하고, JAR 생성/실행 단계에서 드러나는 classpath, 서드파티 JAR, 런타임 모듈 접근 문제를 처리하는 것이다.

## 3단계 후보 분석: AIM 코드 제거 영향 검토

### 배경

VUE에는 AOL Instant Messenger 기반 협업 기능이 남아 있다. AIM 서비스 자체가 오래전에 종료된 서비스이고, macOS 15용 데스크톱 `VUE.app` 목표와도 맞지 않으므로 제거 대상이다. 다만 제거 전에 일반 실행 경로에 영향을 주는지 확인했다.

### 확인한 참조 범위

Java 코드에서 AIM 구현은 다음 영역에 집중되어 있다.

- `VUE2/src/tufts/vue/VueAimPanel.java`
- `VUE2/src/edu/tufts/vue/collab/im/**`
- `VUE2/src/edu/tufts/vue/collab/im/security/**`

`VueAimPanel`은 다음 AIM 구현 클래스를 직접 사용한다.

- `edu.tufts.vue.collab.im.VUEAim`
- `edu.tufts.vue.collab.im.BasicConn`
- `edu.tufts.vue.collab.im.ChatConn`
- `edu.tufts.vue.collab.im.ChatConnListener`
- `net.kano.joscar.*`

`edu/tufts/vue/collab/im` 패키지는 22개 파일로 구성되어 있으며, 대부분 `net.kano.joscar.*` 기반 OSCAR/AIM 프로토콜 구현이다.

### 실행 경로 영향

현재 소스 기준으로 `new VueAimPanel(...)` 또는 `VueAimPanel`을 Map Info 패널에 추가하는 활성 코드는 발견되지 않았다. `MapInspectorPanel`은 `InfoPanel`, `NotePanel`, `MetadataEditor`, 선택적 Twitter 패널만 추가한다.

따라서 AIM UI는 리소스 문자열과 클래스 파일은 남아 있지만, 기본 데스크톱 실행 경로에서 생성되지 않는 휴면 기능으로 보인다.

### 빌드/의존성 영향

`build.xml`에는 AIM 구현 때문에 필요한 것으로 보이는 `joscar-0.9.3-bin.jar`가 포함되어 있다.

```text
joscar-0.9.3-bin.jar
```

`javatar.jar`, `jnet.jar`, `jxtaid.jar`, `jxtasecurity.jar`도 같은 오래된 네트워크/협업 계열로 보이나, 현재 검색만으로 AIM 전용이라고 단정하지 않는다. 3단계에서 실제 삭제 후 컴파일 검증으로 범위를 좁힌다.

### 삭제 시 예상 리스크

- 기본 `VUE` 실행에는 영향이 낮다.
- AIM 관련 메뉴/패널이 실제로 노출되지 않는 상태라면 UI 회귀 가능성도 낮다.
- 단, 리소스 키(`im.*`)와 오래된 preference 설명은 남을 수 있으므로 정리 대상이다.
- `joscar-0.9.3-bin.jar`를 배포 JAR에서 제거할 수 있을 가능성이 높다.

### 권장 3단계 작업

1. `VueAimPanel.java` 삭제
2. `edu/tufts/vue/collab/im/**` 삭제
3. `VueResources*.properties`의 `im.*` 및 `AOL IM` 문자열 제거
4. `build.xml`의 `joscar-0.9.3-bin.jar` classpath/distribution 항목 제거
5. `ant clean compile` 실행
6. `ant jar` 실행 전, 남은 `joscar` 참조가 없는지 확인

이 분석 기준으로 AIM 제거는 macOS 15용 데스크톱 `VUE.app` 목표에 부합하며, 기본 실행 경로를 깨뜨릴 가능성은 낮다.

## 3단계: AIM 코드 제거

### 작업일

2026-05-12

### 결정

AOL Instant Messenger 기반 협업 기능은 서비스 자체가 종료된 오래된 기능이고, macOS 15 데스크톱 `VUE.app` 목표에 필요하지 않다. 사전 분석에서 기본 데스크톱 실행 경로에 `VueAimPanel` 생성 코드가 없음을 확인했으므로 AIM 관련 소스와 리소스를 제거했다.

### 제거한 항목

- `VUE2/src/tufts/vue/VueAimPanel.java` 삭제
- `VUE2/src/edu/tufts/vue/collab/im/**` 삭제
- `VUE2/src/edu/tufts/vue/collab/im/security/**` 삭제
- `VUE2/src/tufts/vue/VueResources*.properties`의 `im.*`, `AOL IM`, `AOL Instant Messenger` 리소스 키 삭제
- `VUE2/src/build.xml`의 `joscar-0.9.3-bin.jar` 참조 삭제
  - 전체 third-party JAR 목록
  - minimal JAR 목록
  - 컴파일 classpath

### 확인한 내용

삭제 후 다음 검색을 수행했다.

```sh
rg -n "joscar|VueAimPanel|VUEAim|edu\.tufts\.vue\.collab\.im|net\.kano\.joscar|^im\.|AOL IM|AOL Instant Messenger" VUE2/src --glob '!**/build/**'
```

결과: `VUE2/src` 안에서 남은 AIM/Joscar 참조가 발견되지 않았다.

### 빌드 검증

```sh
cd VUE2/src
ant clean compile
```

결과:

```text
BUILD SUCCESSFUL
Total time: 3 seconds
```

### 남은 문제

- `VUE2/lib/joscar-0.9.3-bin.jar` 파일 자체는 아직 저장소에 남아 있다. 이번 단계에서는 소스와 빌드 참조 제거를 목표로 했으므로, 벤더 JAR 정리는 배포 산출물 정리 단계에서 처리한다.
- 컴파일 경고는 여전히 남아 있다.
  - `source/target 8` obsolete 경고
  - `sun.net.www.protocol.file.FileURLConnection`
  - `sun.java2d.*`
  - `sun.awt.image.ToolkitImage`
  - `Thread.stop()`
  - `finalize()`

### 결론

AIM 관련 소스 제거 후에도 JDK 25 + Ant 1.10.17 환경에서 `ant clean compile`은 성공한다. 다음 단계는 `ant jar` 또는 macOS 앱 패키징 타깃을 실행하여 실행 JAR/classpath/리소스 배치 문제를 확인하는 것이다.

## 4단계: VUE.jar 빌드 시도

### 작업일

2026-05-12

### 목표

macOS `VUE.app` 패키징 전에 독립 실행형 `VUE.jar` 생성이 가능한지 확인한다. `mac-dist` 타깃은 내부적으로 `jar` 타깃에 의존하므로, JAR 생성 문제와 `.app` 패키징 문제를 분리해서 본다.

### 실행 명령

```sh
cd VUE2/src
ant clean jar
```

### 결과

```text
BUILD SUCCESSFUL
Total time: 6 seconds
```

생성된 산출물:

- `/Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar`
- 크기: 약 37 MB

Manifest 확인 결과:

```text
Main-Class: tufts.vue.VUE
Created-By: 25.0.2 (Homebrew)
Ant-Version: Apache Ant 1.10.17
```

JAR 내용 확인:

- `tufts/vue/VUE.class` 포함
- `tufts/vue/VueResources.properties` 포함
- 삭제한 AIM 항목(`VueAimPanel`, `edu/tufts/vue/collab/im`, `joscar`)은 `VUE.jar`에서 발견되지 않음

### 직접 실행 명령

```sh
java -jar /Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

### 다음 확인 대상

JAR 생성은 성공했지만, 실제 GUI 실행 단계에서는 남아 있는 내부 JDK API 접근(`sun.java2d.*`, `sun.awt.image.ToolkitImage`, `sun.net.www.protocol.file.FileURLConnection`)이나 macOS UI 통합 코드가 JDK 25 런타임에서 예외를 낼 수 있다. 다음 단계는 사용자가 위 명령으로 직접 실행한 결과 또는 우리가 별도 런타임 검증을 수행한 결과를 바탕으로 실행 차단점을 정리하는 것이다.

## 4단계 실행 로그 분석

### 실행 결과 요약

사용자가 다음 명령으로 `VUE.jar`를 직접 실행했고, UI 시작은 완료되었다.

```sh
java -jar /Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

로그상 `UI startup completed`, `main complete`까지 도달했으므로 현재 JAR는 최소 실행 가능하다. 다만 JDK 25 런타임에서 실제 기능 문제로 이어질 수 있는 오류가 확인되었다.

### 실제 문제 1: macOS ApplicationListener 제거

오류:

```text
java.lang.NoClassDefFoundError: com/apple/eawt/ApplicationListener
```

위치:

- `VUE2/src/tufts/vue/VUE.java`
- `VUE2/src/maclib/MacOSX16Safe.java`

영향:

- Finder에서 `.vue` 파일을 더블클릭해 여는 핸들러 설치 실패
- macOS About/Preferences/Quit 이벤트 통합 실패 가능성
- 앱 자체는 계속 실행되지만, 최종 목표인 macOS 15용 `VUE.app`에서는 반드시 정리해야 한다.

추정 해결:

- `com.apple.eawt.ApplicationListener` 기반 코드를 제거한다.
- JDK 9+ 표준 API인 `java.awt.Desktop`의 `setOpenFileHandler`, `setQuitHandler`, `setAboutHandler`, `setPreferencesHandler`로 교체한다.
- `/System/Library/Java/com/apple/cocoa/...` 존재 여부 검사도 현대 macOS에는 맞지 않으므로 제거한다.

### 실제 문제 2: Aqua 내부 클래스 접근 차단

오류:

```text
java.lang.IllegalAccessException: class tufts.vue.gui.GUI cannot access class com.apple.laf.AquaTextFieldBorder
```

위치:

- `VUE2/src/tufts/vue/gui/GUI.java`

영향:

- 텍스트 필드/텍스트 패널의 macOS Aqua 전용 border 설치 실패
- 예외는 잡히고 `LineBorder(Color.blue)`로 대체되므로 실행은 계속된다.
- UI가 의도와 다르게 보일 수 있다.

추정 해결:

- `apple.laf.AquaTextFieldBorder`, `com.apple.laf.AquaTextFieldBorder` 직접 반사 접근을 제거한다.
- `UIManager.getBorder("TextField.border")` 또는 표준 Swing border를 사용한다.

임시 실행 회피책:

```sh
--add-exports=java.desktop/com.apple.laf=ALL-UNNAMED
```

단, 최종 포팅 방향은 `--add-exports` 의존이 아니라 소스 수정이다.

### 실제 문제 3: Castor가 JDK 내부 Xerces 구현을 강제 사용

오류:

```text
Could not instantiate parser com.sun.org.apache.xerces.internal.parsers.SAXParser
Could not instantiate serializer com.sun.org.apache.xml.internal.serialize.XMLSerializer
```

위치:

- `VUE2/src/castor.properties`
- `VUE2/src/tufts/vue/ContentViewer.java`
- `VUE2/src/tufts/vue/DataSetViewer.java`
- `VUE2/src/edu/tufts/vue/ontology/OntManager.java`

영향:

- 온톨로지 저장 실패
- Data Source Viewer 설정 저장 실패
- Castor 기반 XML 저장/로드 경로 전반에서 같은 문제가 반복될 가능성이 높다.

원인:

`VUE2/src/castor.properties`가 JDK 내부 패키지를 직접 지정한다.

```properties
org.exolab.castor.xml.serializer.factory=org.exolab.castor.xml.XercesJDK5XMLSerializerFactory
org.exolab.castor.parser=com.sun.org.apache.xerces.internal.parsers.SAXParser
```

JDK 9 이후 모듈 시스템에서는 `java.xml`이 `com.sun.org.apache.*` 내부 패키지를 unnamed module에 export하지 않으므로 JDK 25에서 접근이 차단된다.

JAR 내부에는 public Xerces 클래스가 이미 포함되어 있음을 확인했다.

```text
org/apache/xerces/parsers/SAXParser.class
org/apache/xml/serialize/XMLSerializer.class
```

추정 해결:

- `VUE2/src/castor.properties`에서 JDK 내부 구현 지정 제거
- public Xerces 구현을 사용하도록 전환

후보 설정:

```properties
org.exolab.castor.parser=org.apache.xerces.parsers.SAXParser
org.exolab.castor.xml.serializer.factory=org.exolab.castor.xml.XercesXMLSerializerFactory
```

또는 Castor 기본 JAXP 경로로 돌아갈 수 있는지 검증한다.

임시 실행 회피책:

```sh
--add-exports=java.xml/com.sun.org.apache.xerces.internal.parsers=ALL-UNNAMED
--add-exports=java.xml/com.sun.org.apache.xml.internal.serialize=ALL-UNNAMED
```

## 5단계 실행: Castor XML 내부 JDK API 의존 제거

### 작업일

2026-05-12

### 변경 사항

`VUE2/src/castor.properties`에서 JDK 내부 Xerces 설정을 제거하고, VUE JAR에 이미 포함되는 공개 Xerces 구현을 사용하도록 변경했다.

변경 후 설정:

```properties
org.exolab.castor.parser=org.apache.xerces.parsers.SAXParser
org.exolab.castor.xml.serializer.factory=org.exolab.castor.xml.XercesXMLSerializerFactory
```

`VUE2/src/tufts/vue/castor.properties`는 deprecated 파일이지만 JAR에 함께 포함되므로, 주석에 남아 있던 `XercesJDK5XMLSerializerFactory` 및 `com.sun.org.apache.*` 예시도 제거했다.

### 빌드

```sh
cd VUE2/src
ant clean jar
```

결과:

```text
BUILD SUCCESSFUL
Total time: 6 seconds
```

생성된 JAR:

```text
/Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

크기:

```text
37 MB
```

### 산출물 확인

`VUE.jar` 내부의 `castor.properties`가 다음 값을 포함하는 것을 확인했다.

```text
org.exolab.castor.parser=org.apache.xerces.parsers.SAXParser
org.exolab.castor.xml.serializer.factory=org.exolab.castor.xml.XercesXMLSerializerFactory
```

JAR 내부에 공개 Xerces 구현이 포함되어 있음을 재확인했다.

```text
org/apache/xerces/parsers/SAXParser.class
org/apache/xml/serialize/XMLSerializer.class
```

### 실행 검증

짧은 실행 검증을 두 차례 수행했다.

```sh
java -jar /Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

확인 결과, 이전에 발생했던 다음 오류는 재현되지 않았다.

```text
Could not instantiate parser com.sun.org.apache.xerces.internal.parsers.SAXParser
Could not instantiate serializer com.sun.org.apache.xml.internal.serialize.XMLSerializer
DataSourceViewer.marshallMap Could not instantiate serializer ...
```

첫 실행에서는 `datasources.xml`이 이전 실패 상태에서 비어 있었던 것으로 보이며 `Premature end of file`이 발생했다. 실행 과정에서 `/Users/andrwj/.vue_2/datasources.xml`이 정상 XML로 다시 생성되었고, 두 번째 실행에서는 `Premature end of file`이 재현되지 않았다.

### 남은 오류

Castor 내부 API 문제와는 별개로 다음 오류는 남아 있다.

```text
java.lang.NoClassDefFoundError: com/apple/eawt/ApplicationListener
java.lang.IllegalAccessException: ... com.apple.laf.AquaTextFieldBorder
OntManager.save: java.io.FileNotFoundException: /Users/andrwj/.vue_2/ontology.xml
```

- `ApplicationListener` 문제는 macOS 앱 이벤트 핸들러 현대화 단계에서 처리한다.
- `AquaTextFieldBorder` 문제는 Swing/Aqua 내부 클래스 직접 접근 제거 단계에서 처리한다.
- `ontology.xml` 문제는 사용자 설정 초기화/기본 파일 생성 경로 문제로 분리해서 확인한다.

### 결론

Castor의 JDK 내부 XML 구현 접근 문제는 해결되었다. 새 `VUE.jar`는 JDK 25에서 `--add-exports` 없이 빌드되고 실행되며, Castor parser/serializer 모듈 접근 오류는 사라졌다.

## 6단계 계획: macOS Application Event API 현대화

### 목표

JDK 25에서 제거된 Apple 전용 `com.apple.eawt.ApplicationListener` 의존을 제거하고, macOS 15에서 `VUE.jar` 및 최종 `VUE.app`가 Finder/애플리케이션 이벤트를 표준 JDK API로 처리하도록 전환한다.

### 현재 원인

실행 로그의 오류:

```text
java.lang.NoClassDefFoundError: com/apple/eawt/ApplicationListener
```

현재 호출 경로:

```text
tufts.vue.VUE.installMacOSXApplicationEventHandlers
tufts.macosx.MacOSX.registerApplicationListener
tufts.macosx.MacOSX16Safe.registerApplicationListener
com.apple.eawt.ApplicationListener
```

문제 파일:

- `VUE2/src/tufts/vue/VUE.java`
- `VUE2/src/maclib/MacOSX16Safe.java`
- `VUE2/src/maclib/MacOSX.java`
- 빌드 산출물에 포함되는 `VUE2/lib/VUE-MacOSX.jar`

### 영향

- Finder에서 `.vue` 파일을 더블클릭해 열기 위한 open-file 이벤트 설치 실패
- macOS 메뉴의 About, Preferences, Quit 이벤트 통합 실패 가능성
- 앱 시작은 계속되지만, 최종 목표인 macOS 15 `VUE.app` 품질 기준에는 맞지 않는다.

### 해결 방향

JDK 9 이후 표준 API인 `java.awt.Desktop`의 macOS-aware handler API를 사용한다.

사용할 API:

- `Desktop.getDesktop().setOpenFileHandler(...)`
- `Desktop.getDesktop().setQuitHandler(...)`
- `Desktop.getDesktop().setAboutHandler(...)`
- `Desktop.getDesktop().setPreferencesHandler(...)`
- `Desktop.isDesktopSupported()`
- `desktop.isSupported(Desktop.Action.APP_OPEN_FILE)`
- `desktop.isSupported(Desktop.Action.APP_QUIT_HANDLER)`
- `desktop.isSupported(Desktop.Action.APP_ABOUT)`
- `desktop.isSupported(Desktop.Action.APP_PREFERENCES)`

### 중요한 결정

현재 `build.xml`의 `target.version`은 `1.8`이지만, 최종 목표는 JDK 25 실행이다. `java.awt.desktop.*` 이벤트 API는 Java 9+ API이므로 JDK 8 런타임 호환성은 목표에서 제외한다. JDK 25로 컴파일/실행하는 현재 포팅 목표에 맞춰 표준 modern API를 직접 사용한다.

### 작업 범위

1. `VUE.java`의 `installMacOSXApplicationEventHandlers()`를 표준 `java.awt.Desktop` 기반으로 교체한다.
2. `/System/Library/Java/com/apple/cocoa/application/NSWindow.class` 존재 여부 검사는 제거한다.
3. 이벤트 동작을 기존 의미와 맞춘다.
   - Open File: 시작 중이면 `VUE.FilesToOpen`에 추가, 시작 후면 `VUE.displayMap(new File(filename))`
   - Quit: `ExitAction.exitVue()` 호출
   - About: `new AboutAction().fire(...)` 호출
   - Preferences: `Actions.Preferences.fire(...)` 호출
4. 각 이벤트는 `desktop.isSupported(...)`로 지원 여부를 확인하고, 미지원이면 debug/info 로그만 남긴다.
5. 기존 `tufts.macosx.MacOSX.registerApplicationListener` 호출을 제거한다.

### 이번 단계에서 하지 않을 일

- `VUE-MacOSX.jar` 전체 제거는 하지 않는다. 다른 코드가 여전히 `tufts.macosx.MacOSX`의 window/icon/fullscreen 보조 메서드를 참조한다.
- `maclib/MacOSX16Safe.java`, `maclib/MacOSX.java` 전체 재설계는 별도 단계로 분리한다.
- `AquaTextFieldBorder` 문제는 다음 UI 내부 API 제거 단계에서 다룬다.

### 검증 계획

1. 정적 검색:

```sh
rg -n "registerApplicationListener|ApplicationListener|ApplicationEvent|com\.apple\.eawt" VUE2/src --glob '!**/build/**'
```

`VUE.java`에서 더 이상 오래된 이벤트 API 경로를 호출하지 않는지 확인한다. `maclib`에 남은 참조는 이번 단계에서는 휴면/레거시 소스로 기록한다.

2. 빌드:

```sh
cd VUE2/src
ant clean jar
```

3. 실행:

```sh
java -jar /Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

4. 로그 성공 기준:

다음 오류가 사라져야 한다.

```text
java.lang.NoClassDefFoundError: com/apple/eawt/ApplicationListener
unable to install handler for Finder double-click to open .vue files
```

5. 기능 확인:

- 앱이 정상 시작해서 `UI startup completed`, `main complete`까지 도달
- 가능하면 `.vue` 파일 인자를 명령행으로 전달해 기존 파일 열기 경로가 유지되는지 확인
- `VUE.app` 생성 후에는 Finder 더블클릭 open-file 이벤트를 별도로 확인

### 실패 시 대안

1. `Desktop` handler API 직접 참조가 `target.version=1.8`과 충돌하면, `target.version`을 더 현대적인 값으로 올리는 계획을 별도로 세운다.
2. 컴파일은 되지만 일부 handler가 macOS에서 unsupported로 나오면, 해당 이벤트는 앱 번들 `Info.plist`/`appbundler` 설정 문제와 함께 `mac-dist` 단계에서 재검증한다.
3. `QuitHandler`에서 종료 취소 처리가 필요하면 `QuitResponse.cancelQuit()`/`performQuit()`를 명확히 연결하도록 추가 조정한다.

### 성공 기준

- 새 `VUE.jar` 빌드 성공
- 실행 로그에서 `ApplicationListener` 오류 제거
- 기존 명령행 파일 열기 경로 유지
- 최종 `VUE.app` 패키징 단계에서 Finder open-file 이벤트 검증이 가능한 상태 확보

## 6단계 실행: macOS Application Event API 현대화

### 작업일

2026-05-12

### 변경 사항

`VUE2/src/tufts/vue/VUE.java`의 `installMacOSXApplicationEventHandlers()`를 `java.awt.Desktop` 기반으로 교체했다.

제거한 동작:

- `/System/Library/Java/com/apple/cocoa/application/NSWindow.class` 검사
- `tufts.macosx.MacOSX.registerApplicationListener(...)` 호출
- `com.apple.eawt.ApplicationListener`에 연결되는 시작 시점 실행 경로

추가한 동작:

- `Desktop.Action.APP_OPEN_FILE` 지원 시 `setOpenFileHandler(...)` 설치
- `Desktop.Action.APP_QUIT_HANDLER` 지원 시 `setQuitHandler(...)` 설치
- `Desktop.Action.APP_ABOUT` 지원 시 `setAboutHandler(...)` 설치
- `Desktop.Action.APP_PREFERENCES` 지원 시 `setPreferencesHandler(...)` 설치
- 각 handler는 `desktop.isSupported(...)`로 지원 여부를 확인한 뒤 설치

기존 의미는 다음처럼 유지했다.

- Open File: 시작 중이면 `VUE.FilesToOpen`에 파일 경로 추가, 시작 후면 `VUE.displayMap(file)` 호출
- Quit: `ExitAction.exitVue()` 호출
- About: `new AboutAction().fire(VUE.class)` 호출
- Preferences: `Actions.Preferences.fire(VUE.class)` 호출

### 남겨둔 범위

`VUE2/src/maclib/**`와 `VUE2/lib/VUE-MacOSX.jar`에는 여전히 `com.apple.eawt.*` 참조가 남아 있다. 이번 단계에서는 `VUE.java`의 시작 시점 이벤트 설치 경로만 현대화했다. 다른 macOS 보조 기능이 아직 `tufts.macosx.MacOSX`의 window/icon/fullscreen 메서드를 참조하므로, 전체 제거는 별도 단계로 남긴다.

### 빌드

```sh
cd VUE2/src
ant clean jar
```

결과:

```text
BUILD SUCCESSFUL
Total time: 6 seconds
```

생성된 JAR:

```text
/Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

Manifest 확인:

```text
Built: May 12 2026 1856
Created-By: 25.0.2 (Homebrew)
Main-Class: tufts.vue.VUE
```

### 실행 검증

짧은 실행 검증:

```sh
java -jar /Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

결과:

```text
UI startup completed.
main complete
```

이전 오류는 재현되지 않았다.

```text
java.lang.NoClassDefFoundError: com/apple/eawt/ApplicationListener
unable to install handler for Finder double-click to open .vue files
```

### 남은 오류

이번 단계와 별개로 다음 오류는 여전히 남아 있다.

```text
java.lang.IllegalAccessException: ... com.apple.laf.AquaTextFieldBorder
OntManager.save: java.io.FileNotFoundException: /Users/andrwj/.vue_2/ontology.xml
MetadataEditor: getValueAt ... no data in model
```

- `AquaTextFieldBorder`는 다음 UI 내부 API 제거 단계의 직접 대상이다.
- `ontology.xml`은 사용자 설정 초기화/기본 파일 생성 문제로 분리한다.
- `MetadataEditor` 로그는 실행을 막지 않았지만, UI 초기화 순서 문제로 추적 대상에 올린다.

### 결론

macOS Application Event API 오류는 `VUE.java` 시작 경로에서 제거되었다. 새 `VUE.jar`는 JDK 25에서 `com.apple.eawt.ApplicationListener` 없이 실행되며, 최종 `VUE.app` 단계에서 Finder open-file 이벤트를 검증할 수 있는 상태가 되었다.

## 7단계 계획: Aqua UI 내부 클래스 접근 제거

### 목표

JDK 25에서 모듈 경계로 차단되는 `com.apple.laf.AquaTextFieldBorder` 직접 접근을 제거한다. 앱은 현재 실행되지만, 시작 로그에 예외가 남고 `VueTextPane`의 border가 임시 debug용 파란색 선으로 대체되므로 UI 품질 문제가 있다.

### 현재 원인

실행 로그:

```text
java.lang.IllegalAccessException: class tufts.vue.gui.GUI cannot access class com.apple.laf.AquaTextFieldBorder
```

직접 원인:

- `VUE2/src/tufts/vue/gui/GUI.java`
- `GUI.installBorder(JTextComponent)`
- `GUI.getAquaTextBorder()`

현재 구현은 다음 순서로 내부 클래스를 반사 로드한다.

```java
Class.forName("apple.laf.AquaTextFieldBorder")
Class.forName("com.apple.laf.AquaTextFieldBorder")
```

JDK 25에서는 `com.apple.laf`가 `java.desktop` 모듈에서 export되지 않으므로 반사 생성이 실패한다. 실패 후에는 `LineBorder(Color.blue)`를 fallback으로 사용한다.

### 영향

- `NotePanel`이 생성하는 `VueTextPane` 초기화 중 오류 로그 발생
- 편집 가능한 텍스트 컴포넌트의 macOS border가 debug용 파란 border로 대체됨
- 앱 시작은 계속되지만, 최종 `VUE.app`의 기본 실행 로그에 오류가 남음

확인된 호출 경로:

```text
NotePanel
VueTextPane.<init>
GUI.installBorder
GUI.getAquaTextBorder
```

### 해결 방향

`com.apple.laf.*` 내부 클래스를 직접 로드하지 않고, Swing의 공개 `UIManager` 기본 border를 사용한다.

우선 후보:

```java
UIManager.getBorder("TextField.border")
UIManager.getBorder("TextPane.border")
UIManager.getBorder("EditorPane.border")
```

권장 적용:

1. `GUI.getAquaTextBorder()`에서 `Class.forName(...)` 제거
2. `UIManager.getBorder("TextField.border")`를 1차 사용
3. 값이 없으면 `UIManager.getBorder("TextPane.border")`를 2차 사용
4. 그래도 없으면 `new LineBorder(AquaFocusBorderDark)` 또는 `new EmptyBorder(...)` 같은 조용한 fallback 사용
5. fallback은 오류 로그가 아니라 debug/info 수준으로 남김

### 중요한 결정

임시 회피책인 다음 옵션은 최종 해결책으로 사용하지 않는다.

```sh
--add-exports=java.desktop/com.apple.laf=ALL-UNNAMED
```

최종 목표는 macOS 15 `VUE.app`가 별도 export 옵션 없이 실행되는 것이다.

### 추가 관찰

`VUE2/src/tufts/vue/gui/VueAquaLookAndFeel.java`는 `apple.laf.AquaLookAndFeel`을 직접 상속한다. 이 클래스는 현재 실행 로그의 직접 원인은 아니지만, 오래된 `apple-laf.jar` 기반 호환성 위험이다. 이번 단계에서는 `AquaTextFieldBorder` 런타임 오류 제거에 집중하고, `VueAquaLookAndFeel` 전체 정리는 별도 UI/LAF 현대화 단계로 남긴다.

### 작업 순서

1. `GUI.getAquaTextBorder()` 구현을 표준 `UIManager` 기반으로 교체
2. `LineBorder(Color.blue)` debug fallback 제거
3. `com.apple.laf.AquaTextFieldBorder`, `apple.laf.AquaTextFieldBorder` 문자열이 남지 않는지 확인
4. `ant clean jar` 실행
5. 새 `VUE.jar` 짧은 실행 검증

### 검증 기준

빌드:

```sh
cd VUE2/src
ant clean jar
```

실행:

```sh
java -jar /Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

성공 조건:

- `BUILD SUCCESSFUL`
- `UI startup completed`, `main complete` 도달
- 실행 로그에서 다음 오류 제거

```text
Mac Aqua GUI init problem
com.apple.laf.AquaTextFieldBorder
java.lang.IllegalAccessException
```

### 실패 시 대안

1. `TextField.border`가 `JTextPane`에 시각적으로 맞지 않으면 `TextPane.border` 또는 `EditorPane.border`를 우선순위로 바꾼다.
2. macOS 기본 border가 없거나 `null`이면 `BorderFactory.createCompoundBorder(...)`로 VUE 자체 border를 만든다.
3. `VueAquaLookAndFeel`에서 추가 Aqua 내부 API 오류가 드러나면, 별도 단계에서 custom Aqua LAF 상속을 제거하고 시스템 LAF 또는 표준 Swing LAF 확장으로 대체한다.

## 7단계 실행: Aqua UI 내부 클래스 접근 제거

### 수정 일자

2026-05-12

### 수정 내용

`VUE2/src/tufts/vue/gui/GUI.java`의 `GUI.getAquaTextBorder()` 구현을 표준 Swing `UIManager` 기반으로 교체했다.

제거한 접근:

```java
Class.forName("apple.laf.AquaTextFieldBorder")
Class.forName("com.apple.laf.AquaTextFieldBorder")
```

새 동작:

1. `UIManager.getBorder("TextField.border")` 사용
2. 없으면 `UIManager.getBorder("TextPane.border")` 사용
3. 없으면 `UIManager.getBorder("EditorPane.border")` 사용
4. 모두 없으면 `LineBorder(AquaFocusBorderDark)`로 조용히 fallback

디버그용 `LineBorder(Color.blue)` fallback도 제거했다.

### 빌드 결과

```sh
cd /Users/andrwj/Develops/github/VUE/VUE2/src
ant clean jar
```

결과:

```text
BUILD SUCCESSFUL
Total time: 6 seconds
```

새 JAR 위치:

```text
/Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

### 실행 검증

검증 명령:

```sh
java -jar /Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

확인된 정상 로그:

```text
UI startup completed.
main complete
```

다음 오류는 더 이상 재현되지 않았다.

```text
Mac Aqua GUI init problem
AquaTextFieldBorder
IllegalAccessException
```

### 남은 로그

이번 단계와 직접 관련 없는 잔여 로그:

```text
OntManager.save: java.io.FileNotFoundException: /Users/andrwj/.vue_2/ontology.xml
EditorManager: editor not ready to produce value ... FontEditorPanel ... NullPointerException
LWComponent: setCreated erasing ...
LayersUI: getActiveLayer when map is null
```

이 중 `ontology.xml`은 사용자 설정 디렉터리 초기화/저장 경로 문제로 보이며, `FontEditorPanel` 경고는 UI 컴포넌트 초기화 순서 문제로 분리해서 조사해야 한다.

## 8단계 실행: 기본 폰트, 색상, 설정 폴더, 버전 조정

### 수정 일자

2026-05-12

### 목표

JDK 25 실행 안정화 이후, macOS 15용 앱 패키징 전에 기본 사용자 경험과 식별 값을 조정한다.

요청된 변경:

1. 한국어를 지원하는 `Pretendard Variable`을 기본 폰트로 지정
2. Shape background color를 `#f1f0ed`로 변경
3. macOS 기본 사용자 설정 폴더를 `.vue`로 변경
4. 앱 버전을 `4.1.0`으로 변경

### 수정 내용

버전:

- `VUE2/src/build.xml`
  - `version=4.0.0`에서 `version=4.1.0`으로 변경
- `VUE2/src/tufts/vue/VueResources.properties`
  - `info.VUEVersion=4.1.0`
  - `vue.version=4.1.0`

사용자 설정 폴더:

- `VUE2/src/tufts/vue/VueUtil.java`
  - `DEFAULT_MAC_FOLDER`를 `.vue_2`에서 `.vue`로 변경

기본 폰트:

- `VUE2/src/tufts/vue/VueResources.properties`
  - `node.font=Pretendard Variable,plain,12`
  - `link.font=Pretendard Variable,plain,11`
  - `text.font=Pretendard Variable,plain,12`
  - `node.dataRow.font=Pretendard Variable,plain,12`
  - `node.dataValue.font=Pretendard Variable,bold,21`
  - `node.icon.font=Pretendard Variable,plain,9`
  - `twitter.tweet.font=Pretendard Variable,plain,16`
  - `twitter.clusterValue.font=Pretendard Variable,bold,21`
- `VUE2/src/tufts/vue/VueConstants.java`
  - 일반 UI용 SansSerif 기본 폰트를 `Pretendard Variable`로 변경
- `VUE2/src/tufts/vue/gui/GUI.java`
  - `LabelFace`, `ValueFace`, `TitleFace`, `StatusFace` 기본 font family를 `Pretendard Variable`로 변경
- `VUE2/src/tufts/vue/gui/VueAquaLookAndFeel.java`
  - Aqua LAF 보정용 기본 폰트를 `Pretendard Variable`로 변경
- `VUE2/src/tufts/vue/VueResources___Mac.properties`
- `VUE2/src/tufts/vue/VueResources_en__Mac.properties`
  - Dock/widget title font를 `Pretendard Variable`로 변경

Shape background color:

- `VUE2/src/tufts/vue/VueResources.properties`
  - `defaultFillColor=F1F0ED`
  - `node.fillColor=F1F0ED`

### 빌드 결과

```sh
cd /Users/andrwj/Develops/github/VUE/VUE2/src
ant clean jar
```

결과:

```text
BUILD SUCCESSFUL
Total time: 6 seconds
```

새 JAR 위치:

```text
/Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

### 실행 검증

검증 명령:

```sh
java -jar /Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

확인된 로그:

```text
VUE version: 4.1.0
CategoryModel: no custom meta-data: /Users/andrwj/.vue/custom.rdfs
Installed DataSources not found; missing /Users/andrwj/.vue/InstalledDataSources.xml
UI startup completed.
main complete
```

JAR 내부 리소스에서도 다음 값이 확인되었다.

```text
info.VUEVersion  = 4.1.0
vue.version=4.1.0
defaultFillColor=F1F0ED
node.fillColor=F1F0ED
node.font=Pretendard Variable,plain,12
link.font=Pretendard Variable,plain,11
text.font=Pretendard Variable,plain,12
node.dataRow.font=Pretendard Variable,plain,12
node.dataValue.font=Pretendard Variable,bold,21
node.icon.font=Pretendard Variable,plain,9
gui.dockWindow.title.font=Pretendard Variable-plain-12
gui.widget.title.font=Pretendard Variable-bold-11
```

### 남은 로그

이번 변경 후에도 다음 기존 잔여 로그는 남아 있다.

```text
OntManager.save: java.io.FileNotFoundException: /Users/andrwj/.vue/ontology.xml
EditorManager: editor not ready to produce value ... FontEditorPanel ... NullPointerException
LWComponent: setCreated erasing ...
LayersUI: getActiveLayer when map is null
```

`DEFAULT_MAC_FOLDER` 변경으로 잔여 로그의 경로는 `.vue_2`가 아니라 `.vue`로 바뀌었다. 다음 단계에서는 `.vue` 디렉터리 초기화 시점과 `ontology.xml` 생성/저장 순서를 조사해야 한다.

## 9단계 실행: 시스템 드래그 중복 시작 오류 방어

### 수정 일자

2026-05-12

### 문제

노드를 드래그할 때 다음 예외가 발생했다.

```text
MapViewer failed processing event java.awt.event.MouseEvent[MOUSE_DRAGGED,...]
java.awt.dnd.InvalidDnDOperationException: Drag and drop in progress
	at java.desktop/java.awt.dnd.DragSource.startDrag(...)
	at java.desktop/java.awt.dnd.DragGestureEvent.startDrag(...)
	at tufts.vue.gui.GUI.startDrag(GUI.java:2936)
	at tufts.vue.gui.GUI.startLWCDrag(GUI.java:2805)
	at tufts.vue.MapViewer.startSystemDrag(MapViewer.java:7501)
	at tufts.vue.MapViewer.mouseDragged(MapViewer.java:7529)
```

### 원인

`MapViewer.mouseDragged`의 기존 코드는 시스템 DnD를 시작하면 더 이상 `mouseDragged`와 `mouseReleased`가 들어오지 않는다고 가정했다.

```java
startSystemDrag(e);
// we'll get no more mouseDragged, and no mouseReleased
return;
```

JDK 25/macOS 15에서는 시스템 DnD가 시작된 뒤에도 같은 마우스 제스처의 후속 `mouseDragged` 이벤트가 들어올 수 있다. 이때 `mouseWasDragged`가 아직 `false`라서 VUE가 `DragGestureEvent.startDrag`를 다시 호출하고, AWT는 이미 진행 중인 DnD가 있으므로 `InvalidDnDOperationException`을 던진다.

### 수정 내용

`VUE2/src/tufts/vue/MapViewer.java`:

- `systemDragInitiated` 플래그 추가
- 시스템 드래그 시작 직전에 `mouseWasDragged=true`, `systemDragInitiated=true` 설정
- 같은 마우스 제스처에서 뒤따르는 `mouseDragged`는 즉시 무시
- 혹시 `mouseReleased`가 전달되면 로컬 move/drop 처리로 이어지지 않도록 상태를 정리하고 반환

`VUE2/src/tufts/vue/gui/GUI.java`:

- `DragGestureEvent.startDrag(...)`에서 `InvalidDnDOperationException`을 잡아 이벤트 처리 루프까지 전파되지 않게 방어
- 중복 드래그 시작은 debug 로그로만 남김

### 빌드 결과

```sh
cd /Users/andrwj/Develops/github/VUE/VUE2/src
ant clean jar
```

결과:

```text
BUILD SUCCESSFUL
Total time: 6 seconds
```

새 JAR 위치:

```text
/Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

### 실행 검증

짧은 기동 검증 결과:

```text
VUE version: 4.1.0
UI startup completed.
main complete
```

기동 로그에서는 다음 드래그 관련 오류가 출력되지 않았다.

```text
InvalidDnDOperationException
Drag and drop in progress
MapViewer failed processing event
```

단, 이 문제는 실제 마우스 드래그 이벤트 타이밍에서 발생하므로 최종 확인은 새 `VUE.jar`를 직접 실행한 뒤 노드 드래그로 재현 여부를 확인해야 한다.

## 10단계 실행: macOS 폰트 크기 감소 단축키 충돌 수정

### 수정 일자

2026-05-12

### 문제

노드에 focus를 준 뒤 `Shift-Cmd-=`를 누르면 폰트가 커지지만, 대칭 동작이어야 하는 `Shift-Cmd--`는 폰트가 작아지지 않고 줌아웃으로 처리된다.

관련 액션:

```java
Actions.FontSmaller: Shift-Cmd-Minus
Actions.FontBigger:  Shift-Cmd-Equals
Actions.ZoomOut:     Cmd-Minus
Actions.ZoomIn:      Cmd-Equals
```

### 원인

기존 액션 정의 자체는 `FontSmaller`가 `Shift-Cmd--`에 정상 배정되어 있다.

```java
new LWCAction(..., keyStroke(KeyEvent.VK_MINUS, COMMAND+SHIFT))
```

그러나 macOS/JDK 25 조합에서는 `Shift-Cmd--` 입력이 메뉴 accelerator 처리 단계에서 `Cmd--` 줌아웃과 충돌할 수 있다. `Shift-Cmd-=`는 font bigger로 처리되지만 minus 쪽은 raw key event가 메뉴 accelerator로 넘어가기 전에 별도 보정이 필요하다.

### 수정 내용

`VUE2/src/tufts/vue/gui/VueMenuBar.java`:

- `FocusManager`가 전달하는 unconsumed key event의 진입점인 `doProcessKeyEvent`에서 macOS `Shift-Cmd--`를 먼저 검사한다.
- 조건:
  - macOS
  - `KEY_PRESSED`
  - `Meta` + `Shift`
  - `Control`/`Alt` 없음
  - key code가 `VK_MINUS`, `VK_SUBTRACT`, `VK_UNDERSCORE` 중 하나이거나 key char가 `_` 또는 `-`
- 조건에 맞고 `Actions.FontSmaller`가 enabled이면 `Actions.FontSmaller.fire(e)`를 직접 호출하고 이벤트를 소비한다.
- 이렇게 하면 `Actions.ZoomOut`의 `Cmd--` accelerator로 떨어지기 전에 폰트 감소 액션이 우선 처리된다.

### 빌드 결과

```sh
cd /Users/andrwj/Develops/github/VUE/VUE2/src
ant clean jar
```

결과:

```text
BUILD SUCCESSFUL
Total time: 6 seconds
```

새 JAR 위치:

```text
/Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

### 실행 검증

짧은 기동 검증 결과:

```text
VUE version: 4.1.0
UI startup completed.
main complete
```

이 문제는 실제 키 입력 이벤트와 선택 상태가 필요하므로 최종 확인은 새 `VUE.jar`에서 노드를 선택한 뒤 다음 두 단축키를 직접 눌러 확인해야 한다.

```text
Shift-Cmd-=  -> 폰트 증가
Shift-Cmd--  -> 폰트 감소
```

`Shift-Cmd--` 입력 중 화면 줌 배율이 변하지 않아야 한다.

### 후속 확인

사용자 확인 결과 이 보정은 기대대로 동작하지 않았다. `Shift-Cmd--`는 여전히 줌아웃으로 먼저 처리되었다. 따라서 `VueMenuBar`의 raw key event 보정 접근은 제거하고, 줌 기능이 `Cmd` 단축키를 우선 사용하도록 두며 폰트 크기 조정 단축키를 `Ctrl` 기반으로 변경한다.

## 11단계 실행: 폰트 크기 단축키를 Ctrl 기반으로 변경

### 수정 일자

2026-05-12

### 목표

macOS에서 줌 기능은 기존 `Cmd-=` / `Cmd--` 단축키를 유지하고, 노드 폰트 크기 조정은 충돌하지 않는 `Ctrl-=` / `Ctrl--` 단축키로 이동한다.

새 정책:

```text
Cmd-=   -> Zoom In
Cmd--   -> Zoom Out
Ctrl-=  -> Font Bigger
Ctrl--  -> Font Smaller
```

폰트 크기 정책:

- 증가: 항상 `1pt`씩 증가
- 감소: 항상 `1pt`씩 감소
- 최소 크기: `7pt`
- 최대 크기: 별도 상한 없음

### 수정 내용

`VUE2/src/tufts/vue/Actions.java`:

```java
FontSmaller: keyStroke(KeyEvent.VK_MINUS, CTRL)
FontBigger:  keyStroke(KeyEvent.VK_EQUALS, CTRL)
```

기존 `FontSmaller`의 `2pt` 단위 감소 로직을 제거하고, `size > 7`인 경우에만 `1pt` 감소하도록 바꾸었다.

기존 `FontBigger`의 짝수 크기 기준 `2pt` 증가 로직을 제거하고, 항상 `1pt` 증가하도록 바꾸었다.

`VUE2/src/tufts/vue/gui/VueMenuBar.java`:

- 이전 단계에서 추가했던 `handleMacFontSmallerShortcut` raw key event 보정은 제거했다.
- 키 이벤트를 메뉴 accelerator보다 먼저 가로채는 방식은 사용하지 않는다.

### 빌드 결과

```sh
cd /Users/andrwj/Develops/github/VUE/VUE2/src
ant clean jar
```

결과:

```text
BUILD SUCCESSFUL
Total time: 6 seconds
```

새 JAR 위치:

```text
/Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

### 실행 검증

짧은 기동 검증 결과:

```text
VUE version: 4.1.0
UI startup completed.
main complete
```

단축키 정의 검색 결과:

```text
FontSmaller -> Ctrl-Minus
FontBigger  -> Ctrl-Equals
ZoomIn      -> Cmd-Equals
ZoomOut     -> Cmd-Minus
```

최종 확인은 새 `VUE.jar`에서 노드를 선택한 뒤 다음 동작으로 진행한다.

```text
Ctrl-=  -> 폰트 크기 1pt 증가
Ctrl--  -> 폰트 크기 1pt 감소, 7pt 미만으로 내려가지 않음
Cmd-=   -> 줌 인
Cmd--   -> 줌 아웃
```

### 후속 확인

사용자 확인 결과 `Ctrl-=` / `Ctrl--` 기반 폰트 크기 조정은 기대대로 동작했다.

## 12단계 실행: Bold 단축키를 Font Weight 조절로 변경

### 수정 일자

2026-05-12

### 목표

기존 `Cmd+B`의 Java `Font.BOLD` 토글 동작을 중단하고, 노드 텍스트의 font weight 값을 100 단위로 순환 조정한다.

새 정책:

```text
Cmd+B       -> font weight 100 증가, 900 다음은 100
Shift-Cmd+B -> font weight 100 감소, 100 다음은 900
```

### 문제점

기존 구현은 `font.style`에 Java `Font.BOLD` 비트를 XOR 하는 방식이었다. 이 방식은 variable font의 100-900 weight 축을 표현할 수 없고, 증가/감소형 조절에도 맞지 않는다.

### 수정 내용

`VUE2/src/tufts/vue/LWComponent.java`:

- `font.weight` 서브 속성을 추가했다.
- 허용 범위는 100-900, 기본값은 400으로 두었다.
- Java2D 렌더링에는 `TextAttribute.WEIGHT`를 사용한다.
- CSS `font-weight`도 새 `font.weight` 속성으로 들어오도록 연결했다.
- 기존 파일의 `Font.BOLD` 값은 호환을 위해 weight 700으로 해석한다.
- 저장 시 `fontWeight` XML 요소를 추가로 기록한다.

`VUE2/src/tufts/vue/Actions.java`:

- `FontBold` 액션은 `Cmd+B`에서 `font.weight`를 100 증가시키도록 변경했다.
- `FontWeightSmaller` 액션을 추가해 `Shift-Cmd+B`에서 `font.weight`를 100 감소시키도록 했다.
- weight 액션 실행 시 기존 legacy `Font.BOLD` 비트는 제거해 새 weight 값이 우선 적용되도록 했다.

`VUE2/src/tufts/vue/gui/VueMenuBar.java`:

- `FontWeightSmaller` 액션을 Format/Text 메뉴에 등록해 Swing accelerator가 동작하도록 했다.

`VUE2/src/tufts/vue/resources/lw_mapping_1_1.xml`, `lw_mapping_1_0.xml`, `lw_mapping_resource_fix.xml`:

- `XMLfontWeight` 매핑을 추가했다.

`VUE2/src/tufts/vue/VueResources.properties`:

- `menu.format.font.fontweightsmaller=Weight Down` 리소스를 추가했다.

### 빌드 결과

```sh
cd /Users/andrwj/Develops/github/VUE/VUE2/src
ant clean jar
```

결과:

```text
BUILD SUCCESSFUL
```

새 JAR 위치:

```text
/Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

### 실행 검증

짧은 기동 검증 결과:

```text
VUE version: 4.1.0
UI startup completed.
main complete
```

실행 로그에서 새 Castor 매핑(`fontWeight`) 로딩으로 인한 즉시 오류는 발견되지 않았다. `/Users/andrwj/.vue/ontology.xml` 부재 로그는 사용자 설정 파일이 아직 없는 상태의 기존 초기화 로그이며, 이번 변경과 직접 관련된 오류는 아니다.

최종 확인은 새 `VUE.jar`에서 노드를 선택한 뒤 다음 동작으로 진행한다.

```text
Cmd+B        -> 기본 400에서 500,600,...,900,100 순환 증가
Shift-Cmd+B  -> 기본 400에서 300,200,100,900,... 순환 감소
```

## 13단계 실행: Pretendard 9개 Weight Face 직접 적용

### 수정 일자

2026-05-12

### 문제점

`TextAttribute.WEIGHT`만 변경하면 macOS 15 / OpenJDK 25 환경에서 `Pretendard Variable`의 9개 weight가 실제 화면 렌더링 face로 선택되지 않았다. Java font subsystem이 시스템 폰트를 다음과 같은 개별 face로 노출하고 있었기 때문이다.

```text
PretendardVariable-Thin
PretendardVariable-ExtraLight
PretendardVariable-Light
PretendardVariable-Regular
PretendardVariable-Medium
PretendardVariable-SemiBold
PretendardVariable-Bold
PretendardVariable-ExtraBold
PretendardVariable-Black
```

따라서 `font.weight` 숫자만 바꾸는 방식은 700 근처에서 synthetic bold처럼 보이는 변화만 만들고, Pretendard의 실제 9개 weight를 쓰지 못했다.

### 수정 내용

`VUE2/src/tufts/vue/LWComponent.java`:

- weight 100-900을 Pretendard face 이름에 직접 매핑했다.

```text
100 -> PretendardVariable-Thin
200 -> PretendardVariable-ExtraLight
300 -> PretendardVariable-Light
400 -> PretendardVariable-Regular
500 -> PretendardVariable-Medium
600 -> PretendardVariable-SemiBold
700 -> PretendardVariable-Bold
800 -> PretendardVariable-ExtraBold
900 -> PretendardVariable-Black
```

- `Pretendard` family도 같은 방식으로 `Pretendard-Thin` ... `Pretendard-Black` face에 매핑했다.
- 렌더링 시 Java `Font.BOLD` 비트는 사용하지 않고, italic 비트만 유지한다. weight는 face 이름으로 결정한다.

`VUE2/src/tufts/vue/TextBox.java`, `VUE2/src/tufts/vue/gui/GUI.java`:

- Swing text document에 font family를 넣을 때 `f.getFamily()` 대신 `f.getFontName()`을 사용하도록 변경했다.
- 이유: `getFamily()`는 모든 Pretendard weight를 `Pretendard Variable`로 접어버리므로 편집 UI에서 정확한 face가 손실된다.

### 로그 분석 및 보정

사용자가 보고한 로그는 font weight 렌더링 실패와 직접 관련이 없었다.

`OntManager.save: FileNotFoundException: /Users/andrwj/.vue/ontology.xml`:

- 실제로는 `save()`가 아니라 `load()` 중 저장된 ontology 파일이 아직 없어서 발생한 로그였다.
- 메시지명도 `save`로 잘못 찍고 있었다.
- 저장 파일이 없으면 정상 초기 상태로 보고 INFO 로그만 남기도록 변경했다.

`FontEditorPanel$17`, `FontEditorPanel$18` NPE WARN:

- Font editor 버튼이 생성되기 전에 editor registration이 `produceValue()`를 호출해서 발생했다.
- font weight 문제와 직접 관련은 없지만 초기화 WARN을 줄이기 위해 null guard를 추가했다.

`LWComponent: setCreated erasing ...`:

- 새 맵 생성 중 created timestamp가 초기화 순서상 한 번 덮이는 경고다.
- font weight와 직접 관련은 없다.

`LayersUI: getActiveLayer when map is null`:

- UI startup 중 active map/layer가 아직 연결되기 전 조회되는 경고다.
- font weight와 직접 관련은 없다.

`IMKCFRunLoopWakeUpReliable`:

- macOS Input Method Kit 계층의 런루프 wakeup 메시지다.
- Java font weight 계산이나 VUE model 변경과 직접 관련은 없다.

### 빌드 결과

```sh
cd /Users/andrwj/Develops/github/VUE/VUE2/src
ant clean jar
```

결과:

```text
BUILD SUCCESSFUL
```

새 JAR 위치:

```text
/Users/andrwj/Develops/github/VUE/VUE2/src/build/VUE.jar
```

### 실행 검증

짧은 기동 검증 결과:

```text
VUE version: 4.1.0
OntManager.load: no saved ontology file yet: /Users/andrwj/.vue/ontology.xml
UI startup completed.
main complete
```

이전의 `OntManager.save` ERROR와 `FontEditorPanel` NPE WARN은 재현되지 않았다. `setCreated erasing`과 `LayersUI: getActiveLayer when map is null` 경고는 남아 있으나 이번 font weight 문제와 직접 관련은 없다.

## 14단계 계획: macOS 15용 VUE.app 패키징

### 목표

최종 산출물을 macOS 15에서 실행 가능한 `VUE.app`으로 만들고, `.vue` / `.vpk` 파일을 Finder에서 기본 앱으로 열 수 있게 한다. 또한 실행 중인 VUE 창으로 `.vue` 파일을 Drag & Drop 했을 때 리소스 노드가 아니라 맵 파일로 열리게 한다.

### 계획

1. `ant mac-dist` 산출물의 `Info.plist`에 문서 타입과 UTI를 선언한다.
2. `.vue`, `.vpk` 확장자를 `edu.tufts.vue.map` 타입으로 등록하고 `VUE.app`을 `Editor` / `Owner`로 선언한다.
3. 기존 appbundler가 생성하는 x86_64 런처를 universal Java shell stub으로 교체해 Apple Silicon macOS 15에서 Rosetta 의존을 피한다.
4. 실행 중인 VUE 창으로 `.vue` / `.vpk` 파일이 드롭되면 `VUE.displayMap(file)`로 열도록 `MapDropTarget`을 보정한다.
5. LaunchServices에 앱을 등록하고 기본 핸들러 및 `open file.vue` 실행 경로를 확인한다.

## 14단계 실행: VUE.app 문서 타입 및 Drag & Drop 처리

### 수정 일자

2026-05-12

### 수정 내용

`VUE2/src/build.xml`:

- `mac-dist` target의 `bundleapp`에 `bundleDocument`와 `typeDeclaration`을 추가했다.
- `.vue`, `.vpk` 확장자를 `edu.tufts.vue.map` UTI로 등록했다.
- `LSHandlerRank`는 `Owner`, 역할은 `Editor`로 지정했다.
- appbundler가 생성한 `Contents/MacOS/VUE` x86_64 런처를 기존 `universalJavaApplicationStub` shell launcher로 교체하고 실행 권한을 부여했다.

`VUE2/src/tufts/vue/MapDropTarget.java`:

- 실행 중인 VUE 창으로 `.vue` 또는 `.vpk` 파일을 드롭하면 새 리소스 노드를 만들지 않고 `VUE.displayMap(file)`로 맵을 연다.
- Finder에서 앱 아이콘으로 파일을 드롭하거나 `.vue` 파일을 더블클릭하는 경로는 `Info.plist` 문서 타입 선언과 `Desktop.setOpenFileHandler` 경로가 담당한다.

### 빌드 결과

```sh
cd /Users/andrwj/Develops/github/VUE/VUE2/src
ant clean mac-dist
```

결과:

```text
BUILD SUCCESSFUL
```

새 앱 위치:

```text
/Users/andrwj/Develops/github/VUE/VUE2/src/build/MacDist/VUE.app
```

### 검증

`Info.plist` 확인:

```text
CFBundleIdentifier = tufts.vue.VUE
CFBundleDocumentTypes -> edu.tufts.vue.map
UTExportedTypeDeclarations -> edu.tufts.vue.map
extensions = vue, vpk
mimeTypes = application/x-vue
LSHandlerRank = Owner
```

LaunchServices 등록:

```sh
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f /Users/andrwj/Develops/github/VUE/VUE2/src/build/MacDist/VUE.app
```

기본 핸들러 확인:

```text
LSCopyDefaultRoleHandlerForContentType("edu.tufts.vue.map") -> tufts.vue.VUE
```

기본 앱 실행 경로 확인:

```sh
open /Users/andrwj/Develops/github/VUE/VUE2/src/tufts/vue/resources/startup.vue
```

결과:

```text
/opt/homebrew/Cellar/openjdk/25.0.2/libexec/openjdk.jdk/Contents/Home/bin/java ... tufts.vue.VUE
```

`open file.vue` 명령으로 `VUE.app`이 정상 기동됨을 확인했다. 검증 후 테스트 프로세스는 종료했다.

### 사용자가 직접 확인할 명령

특정 파일을 명시적으로 현재 빌드된 앱으로 열기:

```sh
open -n -a /Users/andrwj/Develops/github/VUE/VUE2/src/build/MacDist/VUE.app /path/to/file.vue
```

기본 앱 연결을 통한 열기:

```sh
open /path/to/file.vue
```

## 15단계 실행: 인수 없는 시작 시 startup 문서 로드

### 수정 일자

2026-05-12

### 목표

`VUE.jar` 또는 `VUE.app`이 파일 인수 없이 시작되면 빈 `New Map`이 아니라 내장 `startup.vue` 문서를 기본으로 연다.

### 문제점

기존 초기화 코드는 `FilesToOpen`이 비어 있으면 다음처럼 빈 맵을 생성했다.

```text
LWMap("New Map")
```

예전 startup map 로딩 코드는 `VUE.java` 안에 남아 있었지만 주석 처리되어 있었다.

### 수정 내용

`VUE2/src/tufts/vue/VUE.java`:

- `FilesToOpen`이 비어 있을 때 `resource.startmap`으로 지정된 `/tufts/vue/resources/startup.vue`를 로드하도록 변경했다.
- startup map은 JAR 내부 리소스이므로 `setFile(null)`과 `markAsSaved()`를 적용해 내장 리소스를 저장 대상으로 오해하지 않게 했다.
- startup map 로딩 실패 시 기존처럼 빈 `New Map`으로 fallback한다.
- Finder open-file 이벤트가 늦게 도착하는 경우를 대비해, 수정되지 않은 startup placeholder가 떠 있는 상태에서 실제 파일을 열면 해당 startup map을 자동으로 닫도록 했다.

`VUE2/src/tufts/vue/action/ActionUtil.java`:

- `jar:file:...!/startup.vue` URL을 읽을 때 기존 코드는 로컬 파일이 아니면 모두 원격 URL로 간주하고 `UrlAuthentication.getRedirectedUrl` 경로로 들어갔다.
- 이 경로는 `HttpURLConnection`을 전제하므로 `jar:` URL에서 실패했다.
- `http` / `https` URL만 인증/redirect 경로를 사용하고, `jar:` 등 일반 URL은 `url.openStream()`으로 직접 읽도록 변경했다.
- JAR 내부 리소스처럼 로컬 `File`이 없는 map도 version warning 처리 중 `file.getName()` NPE가 나지 않도록 source 문자열을 fallback 이름으로 사용했다.

### 빌드 결과

```sh
cd /Users/andrwj/Develops/github/VUE/VUE2/src
ant clean mac-dist
```

결과:

```text
BUILD SUCCESSFUL
```

### 검증

`VUE.app` 인수 없는 실행:

```text
ActionUtil: unmarshalling: jar:file:.../VUE.app/Contents/Java/VUE.jar!/tufts/vue/resources/startup.vue; charset=UTF-8
ActionUtil: unmarshalled: LWMap[v0 startup.vue n=31]
VUE: displayMap LWMap[v0 startup.vue n=1]
UI startup completed.
```

`VUE.jar` 인수 없는 실행:

```text
ActionUtil: unmarshalling: jar:file:.../build/VUE.jar!/tufts/vue/resources/startup.vue; charset=UTF-8
ActionUtil: unmarshalled: LWMap[v0 startup.vue n=31]
VUE: displayMap LWMap[v0 startup.vue n=1]
UI startup completed.
```

검증 중 `failed to load startup`, `No reader found`, `Could not get reader`, `Exception restoring` 로그는 재현되지 않았다. 테스트 프로세스는 확인 후 종료했다.

## 16단계 실행: 노드 리소스 배지 텍스트 정렬 보정

### 수정 일자

2026-05-12

### 문제점

노드에 URL 또는 파일 리소스가 포함되어 있을 때 왼쪽 리소스 배지의 `web`, `cfm` 같은 3글자 타입 텍스트가 작은 회색 박스보다 약간 위에 걸쳐 보였다.

원인은 `LWIcon.Resource`가 배지 텍스트를 `TextRow`의 glyph bounds 기준으로 가운데 정렬하고 있었기 때문이다. JDK 25 / Pretendard Variable 9pt 환경에서는 `TextLayout` glyph bounds와 실제 line box가 다르게 계산되어, 배경 박스 안에서 시각적 중심이 위쪽으로 치우쳤다.

### 수정 내용

`VUE2/src/tufts/vue/LWIcon.java`:

- 리소스 배지 텍스트만 `TextRow.draw(...)` 경로에서 분리했다.
- 실제 배경 사각형인 `boxBounds`를 기준으로 텍스트 x/y 위치를 계산한다.
- y 위치는 `FontMetrics`의 `getHeight()`, `getAscent()`를 사용해 line box baseline을 박스 내부에 맞춘다.
- `LWNode` 내부 리소스 배지는 Pretendard 렌더링에서 위로 떠 보이는 현상을 보정하기 위해 baseline을 1px 아래로 내렸다.
- 긴 3글자 타입(`www` 등)이 박스보다 약간 넓을 때는 기존처럼 전체 아이콘 폭 기준 중앙 정렬을 유지해 좌우가 급격히 잘리지 않게 했다.

### 빌드 결과

```sh
cd /Users/andrwj/Develops/github/VUE/VUE2/src
ant clean mac-dist
```

결과:

```text
BUILD SUCCESSFUL
```

### 검증

짧은 `VUE.app` 기동 검증에서 `startup.vue`가 정상 로드되고 UI startup이 완료되었다.

```text
ActionUtil: unmarshalled: LWMap[v0 startup.vue n=31]
VUE: displayMap LWMap[v0 startup.vue n=1]
UI startup completed.
main complete
```

이번 변경과 관련된 렌더링 예외는 발생하지 않았다. 기존 `LayersUI: getActiveLayer when map is null` 및 `screenDim<0` 로그는 startup map 초기 표시 과정에서 남는 별도 경고이며, 리소스 배지 텍스트 baseline 변경과 직접 관련은 없다.
