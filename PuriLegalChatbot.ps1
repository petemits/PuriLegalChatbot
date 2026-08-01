# ======================================================================
# PuriLegalChatbot.ps1 - ENDLESS CONVERSATION MODEL
# Always stays in client mode, never exits
# ======================================================================

# Set working directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptPath

# Create data directory if not exists
$dataDir = ".\ChatData"
if (-not (Test-Path $dataDir)) {
    New-Item -ItemType Directory -Path $dataDir -Force | Out-Null
}

# Configuration
$Config = @{
    CompanyName = "Puri Legal Services"
    CompanyPhone = "(905) 497-0090"
    CompanyEmail = "pls@bell.net"
    CompanyAddress = "808 Britannia Rd W, Unit 207, Mississauga, ON"
    ChatLogFile = ".\ChatData\conversations.log"
    SessionFile = ".\ChatData\session.json"
}

# Conversation memory
$ConversationMemory = @{
    ClientName = ""
    LastTopic = ""
    ConversationCount = 0
    TopicsDiscussed = @()
    StartTime = Get-Date
    LastMessageTime = Get-Date
}

# Knowledge Base - Simple dictionary
$KnowledgeBase = @{
    # Traffic tickets
    "traffic" = @(
        "We handle traffic tickets with 60-65% success rate.",
        "Speeding tickets? We can negotiate reductions.",
        "Red light tickets are serious but we can help defend you.",
        "Traffic violations affect insurance for 3+ years.",
        "We review officer notes and identify procedural errors."
    )
    
    "speeding" = @(
        "Speeding tickets can often be reduced.",
        "How much over the limit were you going?",
        "We analyze speed measurement devices for errors.",
        "First offense? Better chances for reduction.",
        "We negotiate with prosecutors on speeding charges."
    )
    
    "red light" = @(
        "Red light camera tickets require specific defense.",
        "We check camera calibration and timing.",
        "Yellow light timing issues can be a defense.",
        "Red light tickets carry demerit points.",
        "We can help challenge red light camera evidence."
    )
    
    # Small claims
    "small claims" = @(
        "Small claims court handles up to $35,000 disputes.",
        "70% success rate for recovering money.",
        "We draft claims and organize evidence.",
        "Contract disputes? We can help recover funds.",
        "Send demand letter first, then file claim if needed."
    )
    
    "debt" = @(
        "Debt collection through small claims is effective.",
        "How much money are you trying to recover?",
        "Written contracts help your case significantly.",
        "We help with unpaid invoices and contracts.",
        "Document all communications about the debt."
    )
    
    # Landlord tenant
    "landlord" = @(
        "Landlord-tenant issues require LTB procedures.",
        "60% success rate for tenant cases.",
        "60% success rate for landlord cases.",
        "Proper notice is crucial for evictions.",
        "We handle rent disputes and maintenance issues."
    )
    
    "tenant" = @(
        "Tenants have rights for repairs and proper notice.",
        "Document all communication with your landlord.",
        "LTB handles tenant applications for repairs.",
        "Keep records of rent payments and notices.",
        "We help tenants with eviction defense."
    )
    
    "eviction" = @(
        "Evictions require proper N forms and notice periods.",
        "Landlords must follow strict LTB procedures.",
        "Tenants can dispute improper evictions.",
        "Notice periods depend on the reason for eviction.",
        "We represent both landlords and tenants in evictions."
    )
    
    # Immigration
    "immigration" = @(
        "Immigration applications need precision.",
        "75% success rate with previously refused cases.",
        "We help with visas, work permits, sponsorships.",
        "Application errors cause most refusals.",
        "We review entire application package for errors."
    )
    
    "visa" = @(
        "Visitor visas require strong ties to home country.",
        "Work permits need employer support and LMIA.",
        "Study visas require acceptance and funds proof.",
        "Super visa for parents requires medical insurance.",
        "We prepare strong visa applications."
    )
    
    # General
    "hello" = @(
        "Hello! Welcome to Puri Legal Services. How can I help?",
        "Hi there! I'm here to assist with legal matters.",
        "Welcome! What brings you to Puri Legal Services today?"
    )
    
    "help" = @(
        "I can help with: Traffic tickets, Small claims, Landlord-tenant, Immigration.",
        "Services: Traffic defense, Debt recovery, LTB disputes, Visa applications.",
        "Need help with: Speeding tickets, Unpaid debts, Rental issues, Immigration?"
    )
    
    "appointment" = @(
        "I can help you book a FREE consultation.",
        "Would you like to schedule a meeting?",
        "Book a free initial assessment with us."
    )
    
    "contact" = @(
        "Call us: (905) 497-0090",
        "Email: pls@bell.net",
        "Address: 808 Britannia Rd W, Mississauga",
        "Phone: (905) 497-0090 | Email: pls@bell.net"
    )
    
    "cost" = @(
        "Free initial consultation.",
        "Affordable paralegal services.",
        "Discuss fees during free consultation."
    )
    
    "bye" = @(
        "Thank you for chatting. We're here if you need us.",
        "Take care! Call us anytime at (905) 497-0090.",
        "Goodbye! Remember we offer free consultations."
    )
}

# Enhanced response generator with context
function Get-EnhancedResponse {
    param(
        [string]$inputText,
        [hashtable]$memory
    )
    
    $text = $inputText.ToLower().Trim()
    $response = ""
    $topic = ""
    
    # Check for name
    if ($text -match 'my name is (\w+)' -or $text -match 'i am (\w+)' -or $text -match 'call me (\w+)') {
        $name = $matches[1]
        $memory.ClientName = $name
        return "Nice to meet you, $name! How can I help you today?", "introduction"
    }
    
    # If we have name, personalize
    $greeting = if ($memory.ClientName) { "Hi $($memory.ClientName), " } else { "" }
    
    # Check all knowledge base topics
    foreach ($topicKey in $KnowledgeBase.Keys) {
        if ($text -match $topicKey) {
            $responses = $KnowledgeBase[$topicKey]
            $randomIndex = Get-Random -Minimum 0 -Maximum $responses.Count
            $response = $greeting + $responses[$randomIndex]
            $topic = $topicKey
            break
        }
    }
    
    # If no match found
    if ([string]::IsNullOrEmpty($response)) {
        $defaultResponses = @(
            "I understand. Could you tell me more about your situation?",
            "I can help with legal matters. What specifically are you dealing with?",
            "Tell me more about your legal concern.",
            "Are you dealing with traffic tickets, small claims, landlord issues, or immigration?"
        )
        $response = $greeting + ($defaultResponses | Get-Random)
        $topic = "general"
    }
    
    # Update memory
    if ($topic -and $topic -ne "general") {
        $memory.LastTopic = $topic
        if ($topic -notin $memory.TopicsDiscussed) {
            $memory.TopicsDiscussed += $topic
        }
    }
    
    $memory.ConversationCount++
    $memory.LastMessageTime = Get-Date
    
    return $response, $topic
}

# Log conversation
function Log-Conversation {
    param(
        [string]$user,
        [string]$message,
        [string]$topic
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp | User: $user | Message: $message | Topic: $topic"
    
    try {
        Add-Content -Path $Config.ChatLogFile -Value $logEntry -ErrorAction SilentlyContinue
    }
    catch {
        # If logging fails, continue without error
    }
}

# Save session
function Save-Session {
    param([hashtable]$memory)
    
    try {
        $memory | ConvertTo-Json | Set-Content -Path $Config.SessionFile -ErrorAction SilentlyContinue
    }
    catch {
        # Continue if save fails
    }
}

# Load session
function Load-Session {
    if (Test-Path $Config.SessionFile) {
        try {
            $saved = Get-Content $Config.SessionFile | ConvertFrom-Json
            return @{
                ClientName = $saved.ClientName
                LastTopic = $saved.LastTopic
                ConversationCount = $saved.ConversationCount
                TopicsDiscussed = @($saved.TopicsDiscussed)
                StartTime = $saved.StartTime
                LastMessageTime = Get-Date
            }
        }
        catch {
            # Return fresh session if load fails
        }
    }
    
    # Return fresh session
    return @{
        ClientName = ""
        LastTopic = ""
        ConversationCount = 0
        TopicsDiscussed = @()
        StartTime = Get-Date
        LastMessageTime = Get-Date
    }
}

# Show conversation status
function Show-Status {
    param([hashtable]$memory)
    
    $duration = New-TimeSpan -Start $memory.StartTime -End (Get-Date)
    $minutes = [math]::Round($duration.TotalMinutes, 1)
    
    Write-Host ""
    Write-Host "[Conversation: $($memory.ConversationCount) messages | " -NoNewline -ForegroundColor Gray
    Write-Host "Duration: ${minutes}m | " -NoNewline -ForegroundColor Cyan
    if ($memory.ClientName) {
        Write-Host "Client: $($memory.ClientName)]" -ForegroundColor Green
    } else {
        Write-Host "Client: New]" -ForegroundColor Yellow
    }
}

# Book appointment
function Book-Appointment {
    param([hashtable]$memory)
    
    Write-Host ""
    Write-Host "=== BOOK FREE CONSULTATION ===" -ForegroundColor Yellow
    
    if (-not $memory.ClientName) {
        $name = Read-Host "Your name"
        $memory.ClientName = $name
    } else {
        $name = $memory.ClientName
    }
    
    $phone = Read-Host "Phone number"
    $issue = Read-Host "Brief description of issue"
    
    Write-Host ""
    Write-Host "APPOINTMENT REQUESTED:" -ForegroundColor Green
    Write-Host "Client: $name" -ForegroundColor White
    Write-Host "Phone: $phone" -ForegroundColor White
    Write-Host "Issue: $issue" -ForegroundColor White
    Write-Host ""
    Write-Host "We'll contact you within 24 hours." -ForegroundColor Cyan
    Write-Host "Or call us: $($Config.CompanyPhone)" -ForegroundColor White
    
    # Log appointment
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $apptLog = "$timestamp | APPOINTMENT | $name | $phone | $issue"
    Add-Content -Path ".\ChatData\appointments.log" -Value $apptLog -ErrorAction SilentlyContinue
    
    return $true
}

# Main endless chatbot loop
function Start-EndlessChatbot {
    # Load previous session or start new
    $ConversationMemory = Load-Session
    
    # Initial setup
    Clear-Host
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "           PURI LEGAL SERVICES - CLIENT MODE              " -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "System: Ready for client conversations" -ForegroundColor Green
    Write-Host "Mode: Endless prompting (Type 'exit' to restart, 'help' for commands)" -ForegroundColor Cyan
    Write-Host "----------------------------------------------------------" -ForegroundColor Gray
    
    # Initial greeting
    if ($ConversationMemory.ClientName) {
        Write-Host ""
        Write-Host "Welcome back, $($ConversationMemory.ClientName)!" -ForegroundColor Green
        Write-Host "How can I help you today?" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "Assistant: Hello! Welcome to Puri Legal Services." -ForegroundColor Cyan
        Write-Host "I'm here to assist with Ontario legal matters." -ForegroundColor White
    }
    
    # Main endless loop
    while ($true) {
        try {
            Write-Host ""
            
            # Show prompt based on client name
            if ($ConversationMemory.ClientName) {
                $prompt = "$($ConversationMemory.ClientName): "
            } else {
                $prompt = "Client: "
            }
            
            # Get user input
            $userInput = Read-Host $prompt
            
            # Handle special commands
            if ($userInput.ToLower() -eq 'exit') {
                Write-Host ""
                Write-Host "System: Restarting conversation..." -ForegroundColor Yellow
                Write-Host "Starting fresh client session..." -ForegroundColor Cyan
                Write-Host ""
                
                # Save current session
                Save-Session $ConversationMemory
                
                # Reset for new client
                $ConversationMemory = @{
                    ClientName = ""
                    LastTopic = ""
                    ConversationCount = 0
                    TopicsDiscussed = @()
                    StartTime = Get-Date
                    LastMessageTime = Get-Date
                }
                
                Write-Host "Assistant: Hello! Welcome to Puri Legal Services." -ForegroundColor Cyan
                Write-Host "I'm here to assist with Ontario legal matters." -ForegroundColor White
                continue
            }
            
            if ($userInput.ToLower() -eq 'help') {
                Write-Host ""
                Write-Host "=== CLIENT MODE COMMANDS ===" -ForegroundColor Yellow
                Write-Host "- Just chat naturally about your legal issue" -ForegroundColor White
                Write-Host "- 'book' - Schedule free consultation" -ForegroundColor White
                Write-Host "- 'status' - Show conversation info" -ForegroundColor White
                Write-Host "- 'contact' - Show contact information" -ForegroundColor White
                Write-Host "- 'services' - List available services" -ForegroundColor White
                Write-Host "- 'exit' - Start fresh with new client" -ForegroundColor White
                Write-Host "- 'clear' - Clear screen" -ForegroundColor White
                Write-Host ""
                continue
            }
            
            if ($userInput.ToLower() -eq 'status') {
                Show-Status $ConversationMemory
                continue
            }
            
            if ($userInput.ToLower() -eq 'book') {
                Book-Appointment $ConversationMemory
                continue
            }
            
            if ($userInput.ToLower() -eq 'contact') {
                Write-Host ""
                Write-Host "=== CONTACT INFORMATION ===" -ForegroundColor Yellow
                Write-Host "Puri Legal Services" -ForegroundColor White
                Write-Host "Phone: $($Config.CompanyPhone)" -ForegroundColor Cyan
                Write-Host "Email: $($Config.CompanyEmail)" -ForegroundColor Cyan
                Write-Host "Address: $($Config.CompanyAddress)" -ForegroundColor Cyan
                Write-Host "Hours: Mon-Fri 9am-6pm" -ForegroundColor White
                Write-Host ""
                continue
            }
            
            if ($userInput.ToLower() -eq 'services') {
                Write-Host ""
                Write-Host "=== OUR SERVICES ===" -ForegroundColor Yellow
                Write-Host "1. Traffic Tickets Defense" -ForegroundColor White
                Write-Host "   - Speeding, red light, careless driving" -ForegroundColor Gray
                Write-Host "   - 60-65% success rate" -ForegroundColor Green
                
                Write-Host ""
                Write-Host "2. Small Claims Court" -ForegroundColor White
                Write-Host "   - Debt recovery up to $35,000" -ForegroundColor Gray
                Write-Host "   - Contract disputes" -ForegroundColor Gray
                Write-Host "   - 70% success rate" -ForegroundColor Green
                
                Write-Host ""
                Write-Host "3. Landlord-Tenant Board" -ForegroundColor White
                Write-Host "   - Evictions, rent disputes, repairs" -ForegroundColor Gray
                Write-Host "   - 60% success rate" -ForegroundColor Green
                
                Write-Host ""
                Write-Host "4. Immigration Applications" -ForegroundColor White
                Write-Host "   - Visas, work permits, sponsorships" -ForegroundColor Gray
                Write-Host "   - 75% success rate" -ForegroundColor Green
                
                Write-Host ""
                Write-Host "All services include FREE initial consultation." -ForegroundColor Cyan
                Write-Host ""
                continue
            }
            
            if ($userInput.ToLower() -eq 'clear') {
                Clear-Host
                Write-Host "==========================================================" -ForegroundColor Cyan
                Write-Host "           PURI LEGAL SERVICES - CLIENT MODE              " -ForegroundColor White
                Write-Host "==========================================================" -ForegroundColor Cyan
                Write-Host ""
                Write-Host "Screen cleared. Conversation continues..." -ForegroundColor Green
                Write-Host ""
                continue
            }
            
            if ([string]::IsNullOrWhiteSpace($userInput)) {
                continue
            }
            
            # Get and display response
            $response, $topic = Get-EnhancedResponse $userInput $ConversationMemory
            
            Write-Host ""
            Write-Host "Assistant: $response" -ForegroundColor Cyan
            
            # Log the conversation
            Log-Conversation $ConversationMemory.ClientName $userInput $topic
            
            # Show status every 4 messages
            if ($ConversationMemory.ConversationCount % 4 -eq 0) {
                Show-Status $ConversationMemory
            }
            
            # Auto-save session periodically
            if ($ConversationMemory.ConversationCount % 10 -eq 0) {
                Save-Session $ConversationMemory
            }
            
            # Suggest appointment at natural points
            if ($ConversationMemory.ConversationCount -eq 3 -or 
                $ConversationMemory.ConversationCount -eq 6 -or
                ($topic -ne "general" -and $ConversationMemory.ConversationCount -eq 4)) {
                
                Write-Host ""
                Write-Host "Would you like to book a FREE consultation? (Type 'book' or 'yes')" -ForegroundColor Yellow
            }
            
        }
        catch {
            # If any error occurs, just continue the conversation
            Write-Host ""
            Write-Host "Assistant: Let me try that again. How can I help you?" -ForegroundColor Cyan
            continue
        }
    }
}

# Start the endless chatbot
try {
    Start-EndlessChatbot
}
catch {
    # If everything fails, restart
    Write-Host "System restarting..." -ForegroundColor Red
    Start-EndlessChatbot
}