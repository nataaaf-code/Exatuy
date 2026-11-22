package com.examora.service;

import com.examora.dao.QuestionDAO;
import com.examora.model.Question;

import com.itextpdf.text.*;
import com.itextpdf.text.pdf.PdfPCell;
import com.itextpdf.text.pdf.PdfPTable;
import com.itextpdf.text.pdf.PdfWriter;
import org.apache.commons.csv.CSVFormat;
import org.apache.commons.csv.CSVParser;
import org.apache.commons.csv.CSVPrinter;
import org.apache.commons.csv.CSVRecord;

import java.io.*;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Service for importing and exporting questions in CSV and PDF formats
 */
public class QuestionImportExportService {
    private final QuizService quizService;
    private final QuestionDAO questionDAO;

    // CSV Headers
    private static final String[] CSV_HEADERS = {
        "question_text", "option_a", "option_b", "option_c", "option_d",
        "correct_answer", "category", "explanation"
    };

    public QuestionImportExportService() {
        this(new QuizService(), new QuestionDAO());
    }

    QuestionImportExportService(QuizService quizService, QuestionDAO questionDAO) {
        this.quizService = quizService;
        this.questionDAO = questionDAO;
    }

    /**
     * Import questions from CSV file
     * @param inputStream Input stream of CSV file
     * @param quizId Quiz ID to add questions to (null for question bank)
     * @return Import result with count and any errors
     */
    public ImportResult importFromCSV(InputStream inputStream, Integer quizId) {
        ImportResult result = new ImportResult();
        List<Question> questions = new ArrayList<>();

        try (BufferedReader reader = csvReader(inputStream);
             CSVParser csvParser = new CSVParser(reader, CSVFormat.DEFAULT
                 .withFirstRecordAsHeader()
                 .withIgnoreHeaderCase()
                 .withTrim())) {
            Set<String> headers = csvParser.getHeaderMap().keySet().stream()
                    .map(s -> s.replace("\uFEFF", "").toLowerCase(java.util.Locale.ROOT))
                    .collect(Collectors.toSet());
            for (String required : CSV_HEADERS) {
                if (!"category".equals(required) && !"explanation".equals(required)
                        && !headers.contains(required)) {
                    result.addError("Kolom CSV wajib tidak ditemukan: " + required);
                    return result;
                }
            }

            for (CSVRecord record : csvParser) {
                try {
                    Question question = parseCSVRecord(record, quizId);
                    if (question != null) {
                        questions.add(question);
                    }
                } catch (Exception e) {
                    result.addError("Baris " + record.getRecordNumber() + ": " + e.getMessage());
                }
            }

            // Create all valid questions
            for (Question question : questions) {
                try {
                    if (quizId != null) {
                        quizService.addQuestion(
                            quizId,
                            question.getQuestionText(),
                            null, // image path
                            question.getOptionA(),
                            question.getOptionB(),
                            question.getOptionC(),
                            question.getOptionD(),
                            question.getCorrectAnswer(),
                            question.getCategoryId(),
                            question.getExplanation()
                        );
                    } else {
                        questionDAO.create(question);
                    }
                    result.incrementSuccess();
                } catch (Exception e) {
                    result.addError("Gagal menyimpan soal: " + e.getMessage());
                }
            }

        } catch (IOException | IllegalArgumentException e) {
            result.addError("Format CSV tidak valid: " + e.getMessage());
        }

        return result;
    }

    private static BufferedReader csvReader(InputStream inputStream) throws IOException {
        BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream, StandardCharsets.UTF_8));
        reader.mark(1);
        if (reader.read() != '\uFEFF') {
            reader.reset();
        }
        return reader;
    }

    /**
     * Parse a CSV record into a Question object
     */
    private Question parseCSVRecord(CSVRecord record, Integer quizId) throws java.sql.SQLException {
        String questionText = record.get("question_text");
        String optionA = record.get("option_a");
        String optionB = record.get("option_b");
        String optionC = record.get("option_c");
        String optionD = record.get("option_d");
        String correctAnswer = record.get("correct_answer");

        // Validate required fields
        if (questionText == null || questionText.trim().isEmpty()) {
            throw new IllegalArgumentException("Teks pertanyaan tidak boleh kosong");
        }
        if (optionA == null || optionA.trim().isEmpty()) {
            throw new IllegalArgumentException("Opsi A tidak boleh kosong");
        }
        if (optionB == null || optionB.trim().isEmpty()) {
            throw new IllegalArgumentException("Opsi B tidak boleh kosong");
        }
        if (optionC == null || optionC.trim().isEmpty()) {
            throw new IllegalArgumentException("Opsi C tidak boleh kosong");
        }
        if (optionD == null || optionD.trim().isEmpty()) {
            throw new IllegalArgumentException("Opsi D tidak boleh kosong");
        }
        if (correctAnswer == null || correctAnswer.trim().isEmpty()) {
            throw new IllegalArgumentException("Jawaban benar tidak boleh kosong");
        }

        // Validate correct answer
        correctAnswer = correctAnswer.toUpperCase().trim();
        if (!correctAnswer.matches("[ABCD]")) {
            throw new IllegalArgumentException("Jawaban benar harus A, B, C, atau D");
        }

        Question question = new Question();
        question.setQuizId(quizId);
        question.setQuestionText(questionText.trim());
        question.setOptionA(optionA.trim());
        question.setOptionB(optionB.trim());
        question.setOptionC(optionC.trim());
        question.setOptionD(optionD.trim());
        question.setCorrectAnswer(correctAnswer);

        String category = record.isMapped("category") ? record.get("category").trim() : "";
        if (!category.isEmpty()) {
            Integer categoryId = questionDAO.findCategoryIdByName(category);
            if (categoryId == null) {
                throw new IllegalArgumentException("Kategori belum ada: " + category);
            }
            question.setCategoryId(categoryId);
        }

        // Optional: explanation
        String explanation = record.isMapped("explanation") ? record.get("explanation") : null;
        if (explanation != null && !explanation.trim().isEmpty()) {
            question.setExplanation(explanation.trim());
        }

        return question;
    }

    /**
     * Export questions to CSV format
     */
    public String exportToCSV(List<Question> questions) {
        StringWriter writer = new StringWriter();

        try (CSVPrinter csvPrinter = new CSVPrinter(writer, CSVFormat.DEFAULT
             .withHeader(CSV_HEADERS))) {

            for (Question question : questions) {
                csvPrinter.printRecord(
                    question.getQuestionText(),
                    question.getOptionA(),
                    question.getOptionB(),
                    question.getOptionC(),
                    question.getOptionD(),
                    question.getCorrectAnswer(),
                    "",
                    question.getExplanation() != null ? question.getExplanation() : ""
                );
            }

        } catch (IOException e) {
            return "Error generating CSV: " + e.getMessage();
        }

        return writer.toString();
    }

    /**
     * Export questions to PDF format
     */
    public byte[] exportToPDF(List<Question> questions, String title) {
        ByteArrayOutputStream outputStream = new ByteArrayOutputStream();

        try {
            Document document = new Document(PageSize.A4, 50, 50, 50, 50);
            PdfWriter.getInstance(document, outputStream);
            document.open();

            // Add title
            Font titleFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 18, BaseColor.DARK_GRAY);
            Paragraph titleParagraph = new Paragraph(title != null ? title : "Daftar Soal", titleFont);
            titleParagraph.setAlignment(Element.ALIGN_CENTER);
            titleParagraph.setSpacingAfter(20);
            document.add(titleParagraph);

            // Add questions
            Font questionFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 12, BaseColor.BLACK);
            Font optionFont = FontFactory.getFont(FontFactory.HELVETICA, 11, BaseColor.DARK_GRAY);
            Font correctFont = FontFactory.getFont(FontFactory.HELVETICA_BOLD, 11, new BaseColor(0, 128, 0));
            Font explanationFont = FontFactory.getFont(FontFactory.HELVETICA_OBLIQUE, 10, BaseColor.GRAY);

            int questionNumber = 1;
            for (Question question : questions) {
                // Question text
                Paragraph qParagraph = new Paragraph();
                qParagraph.add(new Chunk(questionNumber + ". ", questionFont));
                qParagraph.add(new Chunk(question.getQuestionText(), questionFont));
                qParagraph.setSpacingBefore(15);
                document.add(qParagraph);

                // Options
                String[] options = {"A", "B", "C", "D"};
                String[] optionTexts = {
                    question.getOptionA(),
                    question.getOptionB(),
                    question.getOptionC(),
                    question.getOptionD()
                };

                for (int i = 0; i < options.length; i++) {
                    Paragraph optParagraph = new Paragraph();
                    optParagraph.setIndentationLeft(20);
                    boolean isCorrect = options[i].equals(question.getCorrectAnswer());

                    optParagraph.add(new Chunk("   " + options[i] + ". ", isCorrect ? correctFont : optionFont));
                    optParagraph.add(new Chunk(optionTexts[i], isCorrect ? correctFont : optionFont));
                    if (isCorrect) {
                        optParagraph.add(new Chunk(" (Jawaban Benar)", correctFont));
                    }
                    document.add(optParagraph);
                }

                // Explanation (if exists)
                if (question.getExplanation() != null && !question.getExplanation().isEmpty()) {
                    Paragraph expParagraph = new Paragraph();
                    expParagraph.setIndentationLeft(20);
                    expParagraph.add(new Chunk("   Pembahasan: ", explanationFont));
                    expParagraph.add(new Chunk(question.getExplanation(), explanationFont));
                    document.add(expParagraph);
                }

                questionNumber++;
            }

            // Add statistics table if there are statistics
            boolean hasStats = questions.stream()
                .anyMatch(q -> q.getTotalAttempts() != null && q.getTotalAttempts() > 0);

            if (hasStats) {
                document.add(new Paragraph("\n"));
                Paragraph statsTitle = new Paragraph("Statistik Soal", titleFont);
                statsTitle.setAlignment(Element.ALIGN_CENTER);
                statsTitle.setSpacingBefore(20);
                document.add(statsTitle);

                PdfPTable table = new PdfPTable(new float[]{1, 4, 2, 2, 2});
                table.setWidthPercentage(100);

                // Table header
                String[] headers = {"No", "Pertanyaan", "Percobaan", "Benar", "Tingkat Kesulitan"};
                for (String header : headers) {
                    PdfPCell cell = new PdfPCell(new Phrase(header, questionFont));
                    cell.setBackgroundColor(BaseColor.LIGHT_GRAY);
                    table.addCell(cell);
                }

                // Table data
                int rowNum = 1;
                for (Question question : questions) {
                    if (question.getTotalAttempts() != null && question.getTotalAttempts() > 0) {
                        table.addCell(String.valueOf(rowNum++));
                        table.addCell(truncate(question.getQuestionText(), 50));
                        table.addCell(String.valueOf(question.getTotalAttempts()));
                        table.addCell(String.valueOf(question.getCorrectAttempts()));
                        table.addCell(question.getDifficultyLabel());
                    }
                }

                document.add(table);
            }

            document.close();

        } catch (Exception e) {
            e.printStackTrace();
            return ("Error generating PDF: " + e.getMessage()).getBytes();
        }

        return outputStream.toByteArray();
    }

    /**
     * Generate CSV template for download
     */
    public String generateCSVTemplate() {
        StringWriter writer = new StringWriter();

        try (CSVPrinter csvPrinter = new CSVPrinter(writer, CSVFormat.DEFAULT
             .withHeader(CSV_HEADERS))) {

            // Add example row
            csvPrinter.printRecord(
                "Contoh pertanyaan: Apa ibukota Indonesia?",
                "Jakarta",
                "Bandung",
                "Surabaya",
                "Medan",
                "A",
                "",
                "Jakarta adalah ibukota negara Indonesia sejak kemerdekaan."
            );

        } catch (IOException e) {
            return "Error generating template: " + e.getMessage();
        }

        return writer.toString();
    }

    /**
     * Truncate string to specified length
     */
    private String truncate(String str, int length) {
        if (str == null) return "";
        if (str.length() <= length) return str;
        return str.substring(0, length) + "...";
    }

    /**
     * Import result class
     */
    public static class ImportResult {
        private int successCount;
        private List<String> errors;

        public ImportResult() {
            this.successCount = 0;
            this.errors = new ArrayList<>();
        }

        public void incrementSuccess() {
            this.successCount++;
        }

        public void addError(String error) {
            this.errors.add(error);
        }

        public int getSuccessCount() {
            return successCount;
        }

        public List<String> getErrors() {
            return errors;
        }

        public boolean hasErrors() {
            return !errors.isEmpty();
        }
    }
}
