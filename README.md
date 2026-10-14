# Bài 4: Khai báo GitHub Secrets và cấu hình Đăng nhập Container Registry

## 1. Tổng quan bài tập
- **Mục tiêu:** Tạo bí mật mã hóa an toàn (Repository Secret) lưu trữ Token cá nhân trên GitHub. Cấu hình bước xác thực đăng nhập tự động vào GitHub Container Registry (GHCR) thông qua `docker/login-action@v3`.
- **Thư mục bài tập:** `devops/bt/ss11/ex4/`
- **Tệp kịch bản:** `.github/workflows/ci.yml`
- **Tài liệu báo cáo:** `REPORT.md`

---

## 2. Cấu trúc thư mục dự án
```text
ex4/
├── .github/
│   └── workflows/
│       └── ci.yml               # Workflow tích hợp đăng nhập GHCR với GitHub Secrets
├── gradle/
│   └── wrapper/
│       └── gradle-wrapper.properties
├── src/
│   ├── main/
│   │   ├── java/com/example/demo/
│   │   │   ├── DemoApplication.java
│   │   │   └── controller/
│   │   │       └── HelloController.java
│   │   └── resources/
│   │       └── application.properties
│   └── test/
│       └── java/com/example/demo/
│           ├── DemoApplicationTests.java
│           └── HelloControllerTest.java
├── .gitignore
├── Dockerfile                   # Dockerfile đóng gói ứng dụng Spring Boot
├── build.gradle
├── settings.gradle
├── gradlew
├── gradlew.bat
├── README.md
└── REPORT.md
```

---

## 3. Hướng dẫn từng bước cấu hình Secrets trên GitHub

### Bước 1: Khởi tạo Personal Access Token (PAT)
1. Trên tài khoản GitHub cá nhân, nhấp vào ảnh đại diện góc trên cùng bên phải -> chọn **Settings**.
2. Cuộn xuống menu bên trái dưới cùng -> chọn **Developer settings**.
3. Chọn **Personal access tokens** -> **Tokens (classic)** -> nhấn **Generate new token** (chọn *Generate new token (classic)*).
4. Điền thông tin token:
   - **Note:** `GHCR Automation Token - DevOps SS11`
   - **Expiration:** Chọn `30 days` (hoặc tùy chọn phù hợp)
   - **Select scopes:** Tích chọn **`write:packages`** (hệ thống sẽ tự động tích kèm quyền `read:packages`).
5. Nhấn **Generate token**, sau đó sao chép (Copy) chuỗi mã token vừa sinh (ví dụ: `ghp_xxxxxxxxxxxxxxxxxxxxxx`).

### Bước 2: Thêm Secret vào Repository
1. Mở Repository dự án của bạn trên GitHub.
2. Điều hướng tới tab **Settings** của repository -> chọn **Secrets and variables** ở menu bên trái -> nhấp chọn **Actions**.
3. Nhấn vào nút xanh **New repository secret**.
4. Khai báo các trường thông tin:
   - **Name:** `REGISTRY_TOKEN`
   - **Secret:** Dán mã Personal Access Token đã copy ở Bước 1.
5. Nhấn **Add secret** để lưu lại.

---

## 4. Nội dung tệp kịch bản `.github/workflows/ci.yml`

```yaml
name: Java Spring Boot CI & Registry Auth (Gradle)

on:
  push:
    branches: [ "main" ]

jobs:
  test-build:
    name: Run Unit Tests, Build JAR & Registry Login
    runs-on: ubuntu-latest

    steps:
      - name: Checkout mã nguồn
        uses: actions/checkout@v5

      - name: Thiết lập môi trường Java JDK 17
        uses: actions/setup-java@v5
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: 'gradle'

      - name: Cấp quyền cho Gradle Wrapper
        run: chmod +x gradlew

      - name: Thực thi JUnit Test với Gradle
        run: ./gradlew test

      - name: Đóng gói tệp JAR với Gradle
        run: ./gradlew bootJar

      - name: Lưu trữ thành phẩm JAR Artifact
        uses: actions/upload-artifact@v4
        with:
          name: app-jar
          path: build/libs/*.jar

      - name: Đăng nhập vào GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.REGISTRY_TOKEN }}
```

---

## 5. Kiểm tra kết quả
- Khi đẩy code lên GitHub, truy cập tab **Actions** -> mở chi tiết Job **Run Unit Tests, Build JAR & Registry Login**.
- Mở rộng bước **Đăng nhập vào GitHub Container Registry**, bạn sẽ thấy thông báo:
  ```text
  Logging into ghcr.io...
  Login Succeeded
  ```
- Biến `${{ secrets.REGISTRY_TOKEN }}` được che dấu an toàn thành `***` trên toàn bộ console log để ngăn ngừa rò rỉ bảo mật.
