import FileMintCore
import SwiftUI

struct UserGuideLink: View {
    let language: AppLanguage

    var body: some View {
        Link(FileMintStrings.text(.userGuide, language: language),
             destination: FileMintAbout.guideURL(language: language))
            .accessibilityIdentifier("help.userGuide")
    }
}
