# Build LAND METRICS without installing Flutter on your computer

You can let GitHub build the Android APK in the cloud. You still need a GitHub account and must upload this project to a repository.

## Steps

1. Sign in at https://github.com and create a new repository named `land-metrics`.
2. Upload the contents of this project folder to the repository (including the hidden `.github` folder and its `workflows/build-android.yml` file). Do not upload the ZIP itself as the only repository file; upload/extract the project contents.
3. Commit the files to the `main` branch.
4. Open the repository's **Actions** tab.
5. Select **Build LAND METRICS Android APK** and click **Run workflow** if it has not started automatically after the commit.
6. Wait for the workflow to finish successfully.
7. Open the completed workflow run, scroll to **Artifacts**, and download `land-metrics-android-apk`.
8. Extract that artifact ZIP to get `app-release.apk`, then transfer the APK to your Android phone or tablet and install it.

## Important limitations

- This avoids installing Flutter locally; GitHub installs Flutter on its temporary cloud runner to build the app.
- This project is a starter conversion and must pass the cloud build before you can install it. If the build fails, inspect the Actions log and fix the reported errors.
- This workflow builds Android only. Android tablets use the same APK, though tablet layouts should be tested.
- iOS builds require a macOS/Xcode environment. Installing on a real iPhone/iPad and App Store distribution generally require Apple signing credentials. Android APKs cannot be installed on iOS.
- Supabase credentials, storage policies, authentication, and ad publishing still need to be configured and tested before production.
