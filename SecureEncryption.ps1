# Business Grade File Encryption Software
# PowerShell script with Modern, Professional C# WinForms UI

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    $arguments = "& '" + $MyInvocation.MyCommand.Definition + "'"
    Start-Process powershell -Verb RunAs -ArgumentList $arguments
    exit
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Security

$csharpCode = @"
using System;
using System.IO;
using System.Security.Cryptography;
using System.Windows.Forms;
using System.Drawing;
using System.Security.Principal;
using System.Threading.Tasks;

namespace SecureFileEncryption
{
    public class EncryptionEngine
    {
        private int keySize = 256;
        
        public void SetKeySize(int size)
        {
            keySize = size;
        }

        public string GenerateEncryptionKey()
        {
            byte[] key = new byte[keySize / 8];
            using (var rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(key);
            }
            return Convert.ToBase64String(key);
        }

        public void EncryptFile(string filePath, string outputPath, string key)
        {
            byte[] fileBytes = File.ReadAllBytes(filePath);
            byte[] encryptedBytes = Encrypt(fileBytes, key);
            File.WriteAllBytes(outputPath, encryptedBytes);
        }

        public void DecryptFile(string filePath, string outputPath, string key)
        {
            byte[] encryptedBytes = File.ReadAllBytes(filePath);
            byte[] decryptedBytes = Decrypt(encryptedBytes, key);
            File.WriteAllBytes(outputPath, decryptedBytes);
        }

        private byte[] Encrypt(byte[] data, string key)
        {
            byte[] keyBytes = Convert.FromBase64String(key);
            byte[] iv = new byte[16];
            using (var rng = RandomNumberGenerator.Create())
            {
                rng.GetBytes(iv);
            }

            using (var aes = Aes.Create())
            {
                aes.KeySize = keySize;
                aes.BlockSize = 128;
                aes.Mode = CipherMode.CBC;
                aes.Padding = PaddingMode.PKCS7;
                aes.Key = keyBytes;
                aes.IV = iv;

                using (var encryptor = aes.CreateEncryptor(aes.Key, aes.IV))
                using (var memoryStream = new MemoryStream())
                {
                    memoryStream.Write(iv, 0, iv.Length);
                    using (var cryptoStream = new CryptoStream(memoryStream, encryptor, CryptoStreamMode.Write))
                    {
                        cryptoStream.Write(data, 0, data.Length);
                        cryptoStream.FlushFinalBlock();
                        return memoryStream.ToArray();
                    }
                }
            }
        }

        private byte[] Decrypt(byte[] data, string key)
        {
            if (data.Length < 16)
            {
                throw new ArgumentException("Encrypted data is too short to contain an IV.");
            }

            byte[] keyBytes = Convert.FromBase64String(key);
            byte[] iv = new byte[16];
            Array.Copy(data, 0, iv, 0, iv.Length);
            byte[] encryptedData = new byte[data.Length - iv.Length];
            Array.Copy(data, iv.Length, encryptedData, 0, encryptedData.Length);

            using (var aes = Aes.Create())
            {
                aes.KeySize = keySize;
                aes.BlockSize = 128;
                aes.Mode = CipherMode.CBC;
                aes.Padding = PaddingMode.PKCS7;
                aes.Key = keyBytes;
                aes.IV = iv;

                using (var decryptor = aes.CreateDecryptor(aes.Key, aes.IV))
                using (var memoryStream = new MemoryStream(encryptedData))
                using (var cryptoStream = new CryptoStream(memoryStream, decryptor, CryptoStreamMode.Read))
                using (var resultStream = new MemoryStream())
                {
                    byte[] buffer = new byte[1024];
                    int read;
                    while ((read = cryptoStream.Read(buffer, 0, buffer.Length)) > 0)
                    {
                        resultStream.Write(buffer, 0, read);
                    }
                    return resultStream.ToArray();
                }
            }
        }
    }

    public class SettingsForm : Form
    {
        private ComboBox cmbKeyLength;
        private ComboBox cmbTheme;
        private Button btnApply;
        private EncryptionUI parentForm;

        public SettingsForm(EncryptionUI parent)
        {
            parentForm = parent;
            InitializeComponents();
        }

        private void InitializeComponents()
        {
            this.Text = "Settings";
            this.Size = new Size(320, 220); // Increased size
            this.StartPosition = FormStartPosition.CenterParent;
            this.FormBorderStyle = FormBorderStyle.FixedDialog;
            this.MaximizeBox = false;
            this.MinimizeBox = false;
            this.BackColor = Color.FromArgb(240, 242, 245);
            this.Font = new Font("Segoe UI", 10F);

            Label lblKeyLength = new Label { Text = "Key Length:", Location = new Point(20, 20), AutoSize = true, Font = new Font("Segoe UI", 10F, FontStyle.Bold), ForeColor = Color.FromArgb(33, 37, 41) };
            cmbKeyLength = new ComboBox { Location = new Point(20, 45), Width = 260, DropDownStyle = ComboBoxStyle.DropDownList, BackColor = Color.White, FlatStyle = FlatStyle.Flat };
            cmbKeyLength.Items.AddRange(new object[] { "128-bit", "256-bit", "512-bit" });
            cmbKeyLength.SelectedIndex = 1;
            ToolTip ttKeyLength = new ToolTip();
            ttKeyLength.SetToolTip(cmbKeyLength, "Select encryption key length (higher is more secure).");

            Label lblTheme = new Label { Text = "Theme:", Location = new Point(20, 85), AutoSize = true, Font = new Font("Segoe UI", 10F, FontStyle.Bold), ForeColor = Color.FromArgb(33, 37, 41) };
            cmbTheme = new ComboBox { Location = new Point(20, 110), Width = 260, DropDownStyle = ComboBoxStyle.DropDownList, BackColor = Color.White, FlatStyle = FlatStyle.Flat };
            cmbTheme.Items.AddRange(new object[] { "Light", "Dark" });
            cmbTheme.SelectedIndex = 0;
            ToolTip ttTheme = new ToolTip();
            ttTheme.SetToolTip(cmbTheme, "Choose the application theme.");

            btnApply = new Button { Text = "Apply", Location = new Point(180, 150), Width = 100, Height = 30, BackColor = Color.FromArgb(0, 122, 204), ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Font = new Font("Segoe UI", 10F, FontStyle.Bold) };
            btnApply.FlatAppearance.BorderSize = 0;
            btnApply.Click += BtnApply_Click;
            btnApply.MouseEnter += (s, e) => btnApply.BackColor = Color.FromArgb(30, 142, 224);
            btnApply.MouseLeave += (s, e) => btnApply.BackColor = Color.FromArgb(0, 122, 204);

            this.Controls.Add(lblKeyLength);
            this.Controls.Add(cmbKeyLength);
            this.Controls.Add(lblTheme);
            this.Controls.Add(cmbTheme);
            this.Controls.Add(btnApply);
        }

        private void BtnApply_Click(object sender, EventArgs e)
        {
            int keySize = cmbKeyLength.SelectedIndex == 0 ? 128 : cmbKeyLength.SelectedIndex == 1 ? 256 : 512;
            parentForm.encryptionEngine.SetKeySize(keySize);
            parentForm.ApplyTheme(cmbTheme.SelectedIndex == 0 ? "Light" : "Dark");
            this.Close();
        }
    }

    public class EncryptionUI : Form
    {
        private Panel sidebarPanel;
        private Button btnHome;
        private Button btnSettings;
        private Panel contentPanel;
        private TextBox txtKey;
        private TextBox txtInputFile;
        private TextBox txtOutputFile;
        private Button btnBrowseInput;
        private Button btnBrowseOutput;
        private Button btnEncrypt;
        private Button btnDecrypt;
        private Button btnGenerateKey;
        private Label lblStatus;
        private Label lblKeyTitle;
        private Label lblInputFileTitle;
        private Label lblOutputFileTitle;
        private Label lblHeader;
        private Timer animationTimer;
        private float opacity = 0f;
        public EncryptionEngine encryptionEngine = new EncryptionEngine();
        private ToolTip toolTip;
        private string currentTheme = "Light";

        public EncryptionUI()
        {
            if (!IsRunningAsAdmin())
            {
                MessageBox.Show("This application requires administrative privileges. Please restart with admin rights.", "Admin Rights Required", MessageBoxButtons.OK, MessageBoxIcon.Error);
                Environment.Exit(1);
            }
            InitializeComponents();
            StartFadeInAnimation();
            ShowHomeContent();
        }

        private bool IsRunningAsAdmin()
        {
            using (WindowsIdentity identity = WindowsIdentity.GetCurrent())
            {
                WindowsPrincipal principal = new WindowsPrincipal(identity);
                return principal.IsInRole(WindowsBuiltInRole.Administrator);
            }
        }

        private void InitializeComponents()
        {
            this.Text = "Secure File Encryption";
            this.Size = new Size(750, 500); // Increased size
            this.MinimumSize = new Size(650, 450);
            this.StartPosition = FormStartPosition.CenterScreen;
            this.Font = new Font("Segoe UI", 10F);
            this.FormBorderStyle = FormBorderStyle.Sizable;
            this.BackColor = Color.FromArgb(240, 242, 245);
            this.DoubleBuffered = true;

            toolTip = new ToolTip();

            lblHeader = new Label { Text = "Secure Encryption", Font = new Font("Segoe UI", 14F, FontStyle.Bold), AutoSize = true, Location = new Point(20, 20), ForeColor = Color.FromArgb(33, 37, 41) };
            this.Controls.Add(lblHeader);

            sidebarPanel = new Panel { Location = new Point(0, 60), Size = new Size(150, this.ClientSize.Height - 85), BackColor = Color.FromArgb(233, 236, 239), Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Bottom };
            btnHome = new Button { Text = "Home", Location = new Point(0, 10), Size = new Size(150, 40), FlatStyle = FlatStyle.Flat, BackColor = Color.FromArgb(0, 122, 204), ForeColor = Color.White, Font = new Font("Segoe UI", 10F, FontStyle.Bold), TextAlign = ContentAlignment.MiddleLeft, Padding = new Padding(15, 0, 0, 0) };
            btnHome.FlatAppearance.BorderSize = 0;
            btnHome.Click += BtnHome_Click;
            btnHome.MouseEnter += SidebarButton_MouseEnter;
            btnHome.MouseLeave += SidebarButton_MouseLeave;
            toolTip.SetToolTip(btnHome, "View encryption and decryption tools.");
            btnSettings = new Button { Text = "Settings", Location = new Point(0, 50), Size = new Size(150, 40), FlatStyle = FlatStyle.Flat, BackColor = Color.Transparent, ForeColor = Color.FromArgb(33, 37, 41), Font = new Font("Segoe UI", 10F, FontStyle.Bold), TextAlign = ContentAlignment.MiddleLeft, Padding = new Padding(15, 0, 0, 0) };
            btnSettings.FlatAppearance.BorderSize = 0;
            btnSettings.Click += BtnSettings_Click;
            btnSettings.MouseEnter += SidebarButton_MouseEnter;
            btnSettings.MouseLeave += SidebarButton_MouseLeave;
            toolTip.SetToolTip(btnSettings, "Configure application settings.");
            sidebarPanel.Controls.Add(btnHome);
            sidebarPanel.Controls.Add(btnSettings);
            this.Controls.Add(sidebarPanel);

            contentPanel = new Panel { Location = new Point(150, 60), Size = new Size(this.ClientSize.Width - 150, this.ClientSize.Height - 85), BackColor = Color.FromArgb(240, 242, 245), Anchor = AnchorStyles.Top | AnchorStyles.Left | AnchorStyles.Right | AnchorStyles.Bottom };
            this.Controls.Add(contentPanel);

            lblStatus = new Label { Text = "Ready", Location = new Point(0, this.ClientSize.Height - 25), AutoSize = false, Width = this.ClientSize.Width, Height = 25, BackColor = Color.FromArgb(233, 236, 239), TextAlign = ContentAlignment.MiddleLeft, Padding = new Padding(10, 0, 0, 0), Font = new Font("Segoe UI", 9F), ForeColor = Color.FromArgb(33, 37, 41) };
            lblStatus.Anchor = AnchorStyles.Bottom | AnchorStyles.Left | AnchorStyles.Right;
            this.Controls.Add(lblStatus);

            this.Resize += (s, e) => {
                lblStatus.Width = this.ClientSize.Width;
                lblStatus.Location = new Point(0, this.ClientSize.Height - 25);
                contentPanel.Size = new Size(this.ClientSize.Width - 150, this.ClientSize.Height - 85);
                sidebarPanel.Height = this.ClientSize.Height - 85;
            };
        }

        private void ShowHomeContent()
        {
            contentPanel.Controls.Clear();
            btnHome.BackColor = Color.FromArgb(0, 122, 204);
            btnHome.ForeColor = Color.White;
            btnSettings.BackColor = Color.Transparent;
            btnSettings.ForeColor = currentTheme == "Light" ? Color.FromArgb(33, 37, 41) : Color.FromArgb(200, 200, 200);

            lblKeyTitle = new Label { Text = "Encryption Key", Location = new Point(20, 20), AutoSize = true, Font = new Font("Segoe UI", 10F, FontStyle.Bold), ForeColor = currentTheme == "Light" ? Color.FromArgb(33, 37, 41) : Color.FromArgb(200, 200, 200) };
            txtKey = new TextBox { Location = new Point(20, 45), Width = 450, Height = 30, BorderStyle = BorderStyle.FixedSingle, BackColor = Color.White, Font = new Font("Segoe UI", 10F) };
            toolTip.SetToolTip(txtKey, "Enter or generate an encryption key.");
            btnGenerateKey = new Button { Text = "Generate", Location = new Point(480, 45), Width = 100, Height = 30, BackColor = Color.FromArgb(0, 122, 204), ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Font = new Font("Segoe UI", 10F) };
            btnGenerateKey.FlatAppearance.BorderSize = 0;
            btnGenerateKey.Click += GenerateKey_Click;
            btnGenerateKey.MouseEnter += Button_MouseEnter;
            btnGenerateKey.MouseLeave += Button_MouseLeave;
            toolTip.SetToolTip(btnGenerateKey, "Generate a new encryption key.");

            lblInputFileTitle = new Label { Text = "Input File", Location = new Point(20, 85), AutoSize = true, Font = new Font("Segoe UI", 10F, FontStyle.Bold), ForeColor = currentTheme == "Light" ? Color.FromArgb(33, 37, 41) : Color.FromArgb(200, 200, 200) };
            txtInputFile = new TextBox { Location = new Point(20, 110), Width = 450, Height = 30, BorderStyle = BorderStyle.FixedSingle, BackColor = Color.White, Font = new Font("Segoe UI", 10F) };
            toolTip.SetToolTip(txtInputFile, "Select the file to encrypt or decrypt.");
            btnBrowseInput = new Button { Text = "Browse", Location = new Point(480, 110), Width = 100, Height = 30, BackColor = Color.FromArgb(0, 122, 204), ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Font = new Font("Segoe UI", 10F) };
            btnBrowseInput.FlatAppearance.BorderSize = 0;
            btnBrowseInput.Click += BrowseInput_Click;
            btnBrowseInput.MouseEnter += Button_MouseEnter;
            btnBrowseInput.MouseLeave += Button_MouseLeave;
            toolTip.SetToolTip(btnBrowseInput, "Browse for an input file.");

            lblOutputFileTitle = new Label { Text = "Output File", Location = new Point(20, 150), AutoSize = true, Font = new Font("Segoe UI", 10F, FontStyle.Bold), ForeColor = currentTheme == "Light" ? Color.FromArgb(33, 37, 41) : Color.FromArgb(200, 200, 200) };
            txtOutputFile = new TextBox { Location = new Point(20, 175), Width = 450, Height = 30, BorderStyle = BorderStyle.FixedSingle, BackColor = Color.White, Font = new Font("Segoe UI", 10F) };
            toolTip.SetToolTip(txtOutputFile, "Specify the output file path.");
            btnBrowseOutput = new Button { Text = "Browse", Location = new Point(480, 175), Width = 100, Height = 30, BackColor = Color.FromArgb(0, 122, 204), ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Font = new Font("Segoe UI", 10F) };
            btnBrowseOutput.FlatAppearance.BorderSize = 0;
            btnBrowseOutput.Click += BrowseOutput_Click;
            btnBrowseOutput.MouseEnter += Button_MouseEnter;
            btnBrowseOutput.MouseLeave += Button_MouseLeave;
            toolTip.SetToolTip(btnBrowseOutput, "Browse for an output file location.");

            btnEncrypt = new Button { Text = "Encrypt", Location = new Point(200, 250), Width = 120, Height = 40, BackColor = Color.FromArgb(0, 122, 204), ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Font = new Font("Segoe UI", 11F, FontStyle.Bold) };
            btnEncrypt.FlatAppearance.BorderSize = 0;
            btnEncrypt.Click += Encrypt_Click;
            btnEncrypt.MouseEnter += Button_MouseEnter;
            btnEncrypt.MouseLeave += Button_MouseLeave;
            toolTip.SetToolTip(btnEncrypt, "Encrypt the selected file.");

            btnDecrypt = new Button { Text = "Decrypt", Location = new Point(330, 250), Width = 120, Height = 40, BackColor = Color.FromArgb(52, 58, 64), ForeColor = Color.White, FlatStyle = FlatStyle.Flat, Font = new Font("Segoe UI", 11F, FontStyle.Bold) };
            btnDecrypt.FlatAppearance.BorderSize = 0;
            btnDecrypt.Click += Decrypt_Click;
            btnDecrypt.MouseEnter += Button_MouseEnter;
            btnDecrypt.MouseLeave += Button_MouseLeave;
            toolTip.SetToolTip(btnDecrypt, "Decrypt the selected file.");

            contentPanel.Controls.Add(lblKeyTitle);
            contentPanel.Controls.Add(txtKey);
            contentPanel.Controls.Add(btnGenerateKey);
            contentPanel.Controls.Add(lblInputFileTitle);
            contentPanel.Controls.Add(txtInputFile);
            contentPanel.Controls.Add(btnBrowseInput);
            contentPanel.Controls.Add(lblOutputFileTitle);
            contentPanel.Controls.Add(txtOutputFile);
            contentPanel.Controls.Add(btnBrowseOutput);
            contentPanel.Controls.Add(btnEncrypt);
            contentPanel.Controls.Add(btnDecrypt);

            ApplyTheme(currentTheme);
        }

        private void StartFadeInAnimation()
        {
            this.Opacity = 0;
            animationTimer = new Timer { Interval = 30 };
            animationTimer.Tick += (s, e) => {
                opacity += 0.1f;
                this.Opacity = opacity;
                if (opacity >= 1f)
                {
                    animationTimer.Stop();
                    animationTimer.Dispose();
                }
            };
            animationTimer.Start();
        }

        private void SidebarButton_MouseEnter(object sender, EventArgs e)
        {
            var btn = (Button)sender;
            if (btn.BackColor != Color.FromArgb(0, 122, 204)) btn.BackColor = Color.FromArgb(248, 249, 250);
        }

        private void SidebarButton_MouseLeave(object sender, EventArgs e)
        {
            var btn = (Button)sender;
            if (btn != btnHome && btn == btnSettings && btnSettings.BackColor != Color.FromArgb(0, 122, 204)) btn.BackColor = Color.Transparent;
            if (btn != btnSettings && btn == btnHome && btnHome.BackColor != Color.FromArgb(0, 122, 204)) btn.BackColor = Color.Transparent;
        }

        private void Button_MouseEnter(object sender, EventArgs e)
        {
            var btn = (Button)sender;
            btn.BackColor = Color.FromArgb(btn.BackColor.R + 20, btn.BackColor.G + 20, btn.BackColor.B + 20);
        }

        private void Button_MouseLeave(object sender, EventArgs e)
        {
            var btn = (Button)sender;
            if (btn == btnEncrypt || btn == btnGenerateKey || btn == btnBrowseInput || btn == btnBrowseOutput) btn.BackColor = Color.FromArgb(0, 122, 204);
            else if (btn == btnDecrypt) btn.BackColor = Color.FromArgb(52, 58, 64);
        }

        private void GenerateKey_Click(object sender, EventArgs e)
        {
            txtKey.Text = encryptionEngine.GenerateEncryptionKey();
            lblStatus.Text = "New encryption key generated.";
        }

        private void BrowseInput_Click(object sender, EventArgs e)
        {
            using (var openFileDialog = new OpenFileDialog())
            {
                openFileDialog.Multiselect = false;
                if (openFileDialog.ShowDialog() == DialogResult.OK)
                {
                    txtInputFile.Text = openFileDialog.FileName;
                    lblStatus.Text = "Input file selected: " + Path.GetFileName(openFileDialog.FileName);
                }
            }
        }

        private void BrowseOutput_Click(object sender, EventArgs e)
        {
            using (var saveFileDialog = new SaveFileDialog())
            {
                saveFileDialog.OverwritePrompt = true;
                if (saveFileDialog.ShowDialog() == DialogResult.OK)
                {
                    txtOutputFile.Text = saveFileDialog.FileName;
                    lblStatus.Text = "Output file set: " + Path.GetFileName(saveFileDialog.FileName);
                }
            }
        }

        private async void Encrypt_Click(object sender, EventArgs e)
        {
            await ProcessFile(true);
        }

        private async void Decrypt_Click(object sender, EventArgs e)
        {
            await ProcessFile(false);
        }

        private void BtnHome_Click(object sender, EventArgs e)
        {
            ShowHomeContent();
        }

        private void BtnSettings_Click(object sender, EventArgs e)
        {
            using (var settingsForm = new SettingsForm(this))
            {
                settingsForm.ShowDialog();
            }
        }

        private async Task ProcessFile(bool isEncryption)
        {
            if (string.IsNullOrEmpty(txtKey.Text))
            {
                MessageBox.Show("Please enter or generate an encryption key.", "Key Required", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            if (string.IsNullOrEmpty(txtInputFile.Text) || !File.Exists(txtInputFile.Text))
            {
                MessageBox.Show("Please select a valid input file.", "Invalid Input File", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            if (string.IsNullOrEmpty(txtOutputFile.Text))
            {
                MessageBox.Show("Please specify an output file.", "Invalid Output File", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                return;
            }

            SetControlsEnabled(false);
            lblStatus.Text = isEncryption ? "Encrypting..." : "Decrypting...";

            try
            {
                await Task.Run(() => {
                    if (isEncryption)
                    {
                        encryptionEngine.EncryptFile(txtInputFile.Text, txtOutputFile.Text, txtKey.Text);
                    }
                    else
                    {
                        encryptionEngine.DecryptFile(txtInputFile.Text, txtOutputFile.Text, txtKey.Text);
                    }
                });
                
                lblStatus.Text = isEncryption ? "Encryption complete!" : "Decryption complete!";
                MessageBox.Show(
                    "Operation completed successfully.\nOutput file: " + txtOutputFile.Text, 
                    "Success", 
                    MessageBoxButtons.OK, 
                    MessageBoxIcon.Information
                );
            }
            catch (Exception ex)
            {
                lblStatus.Text = "Error: " + ex.Message;
                MessageBox.Show(
                    "An error occurred: " + ex.Message, 
                    "Error", 
                    MessageBoxButtons.OK, 
                    MessageBoxIcon.Error
                );
            }
            finally
            {
                SetControlsEnabled(true);
            }
        }

        private void SetControlsEnabled(bool enabled)
        {
            if (btnEncrypt != null) btnEncrypt.Enabled = enabled;
            if (btnDecrypt != null) btnDecrypt.Enabled = enabled;
            if (btnBrowseInput != null) btnBrowseInput.Enabled = enabled;
            if (btnBrowseOutput != null) btnBrowseOutput.Enabled = enabled;
            if (btnGenerateKey != null) btnGenerateKey.Enabled = enabled;
            btnHome.Enabled = enabled;
            btnSettings.Enabled = enabled;
            if (txtKey != null) txtKey.Enabled = enabled;
            if (txtInputFile != null) txtInputFile.Enabled = enabled;
            if (txtOutputFile != null) txtOutputFile.Enabled = enabled;
        }

        public void ApplyTheme(string theme)
        {
            currentTheme = theme;
            if (theme == "Dark")
            {
                this.BackColor = Color.FromArgb(34, 36, 38);
                contentPanel.BackColor = Color.FromArgb(34, 36, 38);
                sidebarPanel.BackColor = Color.FromArgb(40, 42, 44);
                lblStatus.BackColor = Color.FromArgb(40, 42, 44);
                lblStatus.ForeColor = Color.FromArgb(200, 200, 200);
                lblHeader.ForeColor = Color.White;
                if (lblKeyTitle != null) lblKeyTitle.ForeColor = lblInputFileTitle.ForeColor = lblOutputFileTitle.ForeColor = Color.FromArgb(200, 200, 200);
                if (txtKey != null) txtKey.BackColor = txtInputFile.BackColor = txtOutputFile.BackColor = Color.FromArgb(50, 52, 54);
                if (txtKey != null) txtKey.ForeColor = txtInputFile.ForeColor = txtOutputFile.ForeColor = Color.FromArgb(200, 200, 200);
                btnHome.ForeColor = btnSettings.ForeColor = Color.FromArgb(200, 200, 200);
            }
            else // Light
            {
                this.BackColor = Color.FromArgb(240, 242, 245);
                contentPanel.BackColor = Color.FromArgb(240, 242, 245);
                sidebarPanel.BackColor = Color.FromArgb(233, 236, 239);
                lblStatus.BackColor = Color.FromArgb(233, 236, 239);
                lblStatus.ForeColor = Color.FromArgb(33, 37, 41);
                lblHeader.ForeColor = Color.FromArgb(33, 37, 41);
                if (lblKeyTitle != null) lblKeyTitle.ForeColor = lblInputFileTitle.ForeColor = lblOutputFileTitle.ForeColor = Color.FromArgb(33, 37, 41);
                if (txtKey != null) txtKey.BackColor = txtInputFile.BackColor = txtOutputFile.BackColor = Color.White;
                if (txtKey != null) txtKey.ForeColor = txtInputFile.ForeColor = txtOutputFile.ForeColor = Color.FromArgb(33, 37, 41);
                btnHome.ForeColor = btnSettings.ForeColor = Color.FromArgb(33, 37, 41);
            }
        }
    }
}
"@

Add-Type -TypeDefinition $csharpCode -ReferencedAssemblies System.Windows.Forms, System.Drawing, System.Security
$form = New-Object SecureFileEncryption.EncryptionUI
$form.ShowDialog()